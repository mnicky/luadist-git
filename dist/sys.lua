-- System functions

module ("dist.sys", package.seeall)

local cfg = require "dist.config"
local utils = require "dist.utils"
local lfs = require "lfs"

-- TODO test functionality of this module on Windows

-- Return quoted string argument.
function quote(argument)
    assert(type(argument) == "string", "sys.quote: Argument 'argument' is not a string.")

    argument = string.gsub(argument, "\\",  "\\\\")
    argument = string.gsub(argument, "\'",  "'\\''")

    return "'" .. argument .. "'"
end

-- Run the system command (in current directory).
-- Return true on success, nil on fail and log string.
-- When optional 'force_verbose' parameter is true, then the output will be shown
-- even when not in debug or verbose mode.
function exec(command, force_verbose)
    force_verbose = force_verbose or false
    assert(type(command) == "string", "sys.exec: Argument 'command' is not a string.")
    assert(type(force_verbose) == "boolean", "sys.exec: Argument 'force_verbose' is not a boolean.")

    if not (cfg.verbose or cfg.debug or force_verbose) then
        if cfg.arch == "Windows" then
            command = command .. " > NUL 2>&1"
        else
            command = command .. " > /dev/null 2>&1"
        end
    end

    local ok = os.execute(command)

    if ok ~= 0 then
        return nil, "Error when running the command: " .. command
    else
        return true, "Sucessfully executed the command: " .. command
    end
end

-- Execute the 'command' and returns its output as a string.
function capture_output(command)
    assert(type(command) == "string", "sys.exec: Argument 'command' is not a string.")

    local executed, err = io.popen(command, "r")
    if not executed then return nil, "Error running the command '" .. command .. "':" .. err end

    local captured, err = executed:read("*a");
    if not captured then return nil, "Error reading the output of command '" .. command .. "':" .. err end

    executed:close()
    return captured
end

-- Return if specified file or directory exists
function exists(path)
    assert(type(path) == "string", "sys.exists: Argument 'path' is not a string.")

    return lfs.attributes(path)
end

-- Return if file is a file
function is_file(file)
    assert(type(file) == "string", "sys.is_file: Argument 'file' is not a string.")
    return lfs.attributes(file, "mode") == "file"
end

-- Return if dir is a directory
function is_dir(dir)
    assert(type(dir) == "string", "sys.is_dir: Argument 'dir' is not a string.")
    return lfs.attributes(dir, "mode") == "directory"
end

-- Return the current working directory
function current_dir()
    return lfs.currentdir()
end

-- Return iterator over directory dir.
-- If dir does not exist or is not a directory, return nil and error message.
function get_directory(dir)
    dir = dir or current_dir()
    assert(type(dir) == "string", "sys.get_directory: Argument 'dir' is not a string.")
    if is_dir(dir) then
        return lfs.dir(dir)
    else
        return nil, "Error: '".. dir .. "' is not a directory."
    end
end

-- Extract file or directory name from its path
function extract_name(path)
    assert(type(path) == "string", "sys.extract_name: Argument 'path' is not a string.")

    path = path:gsub("\\", "/")

    -- remove the trailing '/' character
    if (path:sub(-1) == "/") then
        path = path:sub(1,-2)
    end

    local name = path:gsub("^.*/", "")
    return name
end

-- Return parent directory of the 'path' or nil if there's no parent directory.
-- If 'path' is file path, return directory the file is in.
function parent_dir(path)
    assert(type(path) == "string", "sys.parent_dir: Argument 'path' is not a string.")

    path = path:gsub("\\", "/")

    -- remove the trailing '/' character
    if (path:sub(-1) == "/") then
        path = path:sub(1,-2)
    end

    local dir = path:gsub(utils.escape_magic(extract_name(path)) .. "$", "")
    if dir == "" then
        return nil
    else
        return dir
    end
end

-- Compose path composed from specified parts or current
-- working directory when no part specified.
function make_path(...)
    local parts = arg
    assert(type(parts) == "table", "sys.make_path: Argument 'parts' is not a table.")

    local path, err
    if parts.n == 0 then
        path, err = current_dir()
    else
        path, err = table.concat(parts, "/")
    end
    if not path then return nil, err end

    return path
end

-- Return absolute path from 'path'
function abs_path(path)
    assert(type(path) == "string", "sys.get_abs_path: Argument 'path' is not a string.")

    local cur_dir, err = current_dir()
    if not cur_dir then return nil, err end

    if path:sub(1,1) == "/" then
        return path
    else
        return make_path(cur_dir, path)
    end
end

-- Return table of all paths in 'dir'
function get_file_list(dir)
    dir = dir or current_dir()
    assert(type(dir) == "string", "sys.get_directory: Argument 'dir' is not a string.")
    if not exists(dir) then return nil, "Error getting file list of '" .. dir .. "': directory doesn't exist." end

    local function collect(path, all_paths)
        for item in get_directory(path) do

            local item_path = make_path(path, item)
            local _, last = item_path:find(dir .. "/", 1, true)
            local path_to_insert = item_path:sub(last + 1)

            if is_file(item_path) then
                table.insert(all_paths, path_to_insert)
            elseif is_dir(item_path) and item ~= "." and item ~= ".." then
                table.insert(all_paths, path_to_insert)
                collect(item_path, all_paths)
            end
        end
    end

    local all_paths = {}
    collect(dir, all_paths)

    return all_paths
end

-- Return time of the last modification of 'file'.
function last_modification_time(file)
    assert(type(file) == "string", "sys.last_modification_time: Argument 'file' is not a string.")
    return lfs.attributes(file, "modification")
end

-- Return the current time (in seconds since epoch).
function current_time()
    return os.time()
end

-- Change the current working directory and return 'true' and previous working
-- directory on success and 'nil' and error message on error.
function change_dir(dir_name)
    assert(type(dir_name) == "string", "sys.change_dir: Argument 'dir_name' is not a string.")
    local prev_dir = current_dir()
    local ok, err = lfs.chdir(dir_name)
    if ok then
        return ok, prev_dir
    else
        return nil, err
    end
end

-- Make a new directory, making also all of its parent directories that doesn't exist.
function make_dir(dir_name)
    assert(type(dir_name) == "string", "sys.make_dir: Argument 'dir_name' is not a string.")
    if exists(dir_name) then
        return true
    else
        local par_dir = parent_dir(dir_name)
        if par_dir then
            local ok, err = make_dir(par_dir)
            if not ok then return nil, err end
        end
        return lfs.mkdir(dir_name)
    end
end

-- Move file (or directory) to the destination directory
function move_to(file_or_dir, dest_dir)
    assert(type(file_or_dir) == "string", "sys.move_to: Argument 'file_or_dir' is not a string.")
    assert(type(dest_dir) == "string", "sys.move_to: Argument 'dest_dir' is not a string.")
    assert(is_dir(dest_dir), "sys.move_to: destination '" .. dest_dir .."' is not a directory.")

    -- Extract file/dir name from its path
    local file_or_dir_name = extract_name(file_or_dir)

    return os.rename(file_or_dir, make_path(dest_dir, file_or_dir_name))
end

-- rename file (or directory) to the new name.
function rename(file, new_name)
    assert(type(file) == "string", "sys.rename: Argument 'file' is not a string.")
    assert(type(new_name) == "string", "sys.rename: Argument 'new_name' is not a string.")
    assert(not exists(new_name), "sys.rename: desired filename already exists.")

    return os.rename(file, new_name)
end

-- Copy 'source' to the destination directory 'dest_dir'.
-- If 'source' is a directory, then recursive copying is used.
-- For non-recursive copying of directories use the make_dir() function.
function copy(source, dest_dir)
    assert(type(source) == "string", "sys.copy: Argument 'file_or_dir' is not a string.")
    assert(type(dest_dir) == "string", "sys.copy: Argument 'dest_dir' is not a string.")
    assert(is_dir(dest_dir), "sys.copy: destination '" .. dest_dir .."' is not a directory.")

    if cfg.arch == "Windows" then
        if is_dir(source) then
            mkdir(make_path(dest_dir, extract_name(source)))
            return exec("xcopy /E /I /Y /Q " .. quote(source) .. " " .. quote(dest_dir .. "\\" .. extract_name(source)))
        else
            return exec("copy /Y " .. quote(source) .. " " .. quote(dest_dir))
        end
    else
        if is_dir(source) then
            return exec("cp -fRH " .. quote(source) .. " " .. quote(dest_dir))
        else
            return exec("cp -fH " .. quote(source) .. " " .. quote(dest_dir))
        end
    end
end

-- Delete the specified file or directory
function delete(path)
    assert(type(path) == "string", "sys.delete: Argument 'path' is not a string.")

    if cfg.arch == "Windows" then
        return exec("rd /S /Q " .. quote(path))
    else
        return exec("rm -rf " .. quote(path))
    end
end
