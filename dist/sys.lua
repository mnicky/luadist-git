-- System functions

module ("dist.sys", package.seeall)

local cfg = require "dist.config"
local lfs = require "lfs"

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

-- Move file or directory to the destination directory
function move(file_or_dir, dest_dir)
    assert(type(file_or_dir) == "string", "sys.move: Argument 'file_or_dir' is not a string.")
    assert(type(dest_dir) == "string", "sys.move: Argument 'dest_dir' is not a string.")

    -- Extract file/dir name from its path
    local file_or_dir_name = extract_name(file_or_dir)

    return os.rename(file_or_dir, dest_dir .. "/" .. file_or_dir_name)
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

    return lfs.mkdir(dir_name)
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
