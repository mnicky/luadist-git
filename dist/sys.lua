-- System functions

module ("dist.sys", package.seeall)

local cfg = require "dist.config"
local lfs = require "lfs"

-- TODO test functionality of this module on Windows

-- Returns quoted string argument.
function quote(argument)
    assert(type(argument) == "string", "sys.quote: Argument 'argument' is not a string.")

    argument = string.gsub(argument, "\\",  "\\\\")
    argument = string.gsub(argument, "\'",  "'\\''")

    return "'" .. argument .. "'"
end

-- Run the system command (in current directory).
-- Return true on success, nil on fail and log string.
function exec(command)
    assert(type(command) == "string", "sys.exec: Argument 'command' is not a string.")

    local ok = os.execute(command)

    if ok ~= 0 then
        return nil, "Error when running the command: " .. command
    else
        return true, "Sucessfully executed the command: " .. command
    end
end

-- Returns if specified file or directory exists
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

    return path:gsub("^.*/", "")
end

-- Return table of all paths in 'dir'
function get_file_list(dir)

    dir = dir or current_dir()

    assert(type(dir) == "string", "sys.get_directory: Argument 'dir' is not a string.")

    if not exists(dir) then return nil, "Error getting file list of '" .. dir .. "': directory doesn't exist." end

    local function collect(path, all_paths)
        for item in get_directory(path) do
            local item_path = path .. "/" .. item
            if is_file(item_path) then
                table.insert(all_paths, "[[" .. item_path:gsub(dir .. "/", "", 1) .. "]]")
            elseif is_dir(item_path) and item ~= "." and item ~= ".." then
                table.insert(all_paths, "[[" .. item_path:gsub(dir .. "/", "", 1) .. "]]")
                collect(item_path, all_paths)
            end
        end
    end

    local all_paths = {}
    collect(dir, all_paths)

    return all_paths
end

-- Return the current working directory
function current_dir()
    return lfs.currentdir()
end

-- Changes the current working directory
function change_dir(dir_name)
    assert(type(dir_name) == "string", "sys.change_dir: Argument 'dir_name' is not a string.")
    return lfs.chdir(dir_name)
end

-- Make a new directory
function make_dir(dir_name)
    assert(type(dir_name) == "string", "sys.make_dir: Argument 'dir_name' is not a string.")
    if exists(dir_name) then
        return true
    else
        return lfs.mkdir(dir_name)
    end
end

-- Move file or directory to the destination directory
function move(file_or_dir, dest_dir)
    assert(type(file_or_dir) == "string", "sys.move: Argument 'file_or_dir' is not a string.")
    assert(type(dest_dir) == "string", "sys.move: Argument 'dest_dir' is not a string.")

    assert(is_dir(dest_dir), "sys.move: destination '" .. dest_dir .."' is not a directory.")

    -- Extract file/dir name from its path
    local file_or_dir_name = extract_name(file_or_dir)

    return os.rename(file_or_dir, dest_dir .. "/" .. file_or_dir_name)
end

-- Copy 'source' to the destination directory 'dest_dir'.
-- If 'source' is a directory, then recursive copying is used.
-- For non-recursive copying of directories use the make_dir() function.
function copy(source, dest_dir)

    assert(type(source) == "string", "sys.copy: Argument 'file_or_dir' is not a string.")
    assert(type(dest_dir) == "string", "sys.copy: Argument 'dest_dir' is not a string.")

    assert(is_dir(dest_dir), "sys.move: destination '" .. dest_dir .."' is not a directory.")

    if (cfg.arch == "Windows") then
        if is_dir(source) then
            mkdir(dest_dir .. "/" .. extract_name(source))
            return exec("xcopy /E /I /Y /Q " .. quote(source) .. " " .. quote(dest_dir .. "\\" .. extract_name(source)))
        else
            return exec("copy /Y " .. quote(source) .. " " .. quote(dest_dir))
        end
    else
        if is_dir(source) then
            return exec("cp -frH " .. quote(source) .. " " .. quote(dest_dir))
        else
            return exec("cp -fH " .. quote(source) .. " " .. quote(dest_dir))
        end
    end
end

-- Delete the specified file or directory
function delete(path)
    assert(type(path) == "string", "sys.delete: Argument 'path' is not a string.")

    if (cfg.arch == "Windows") then
        return exec("rd /S /Q " .. quote(path))
    else
        return exec("rm -rf " .. quote(path))
    end
end




