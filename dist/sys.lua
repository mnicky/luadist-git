-- System functions

module ("dist.sys", package.seeall)

local cfg = require "dist.config"
local lfs = require "lfs"

-- Returns quoted string argument.
function quote(argument)
    assert(type(argument) == "string", "dist.sys: Argument 'argument' is not a string.")

    argument = string.gsub(argument, "\\",  "\\\\")
    argument = string.gsub(argument, "\'",  "'\\''")

    return "'" .. argument .. "'"
end

-- Run the system command (in current directory).
-- Return true on success, nil on fail and log string.
function exec(command)
    assert(type(command) == "string", "dist.sys: Argument 'command' is not a string.")

    local ok = os.execute(command)

    if ok ~= 0 then
        return nil, "Error when running the command: " .. command
    else
        return true, "Sucessfully executed the command: " .. command
    end
end

-- Returns if specified file or directory exists
function exists(path)
    assert(type(path) == "string", "dist.sys: Argument 'path' is not a string.")

    return lfs.attributes(path)
end

-- Rename source path to be the destination path
function move_path(src_path, dest_path)
    assert(type(src_path) == "string", "dist.sys: Argument 'src_path' is not a string.")
    assert(type(dest_path) == "string", "dist.sys: Argument 'dest_path' is not a string.")

    return os.rename(src_path, dest_path)
end

-- Delete the specified file or directory
function delete(path)
    assert(type(path) == "string", "dist.sys: Argument 'path' is not a string.")

    if (cfg.arch == "windows") then
        return exec("rd /S /Q " .. quote(path))
    else
        return exec("rm -rf " .. quote(path))
    end
end
