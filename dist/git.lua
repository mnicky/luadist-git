-- Encapsulated Git functionality

module ("dist.git", package.seeall)

local sys = require "dist.sys"


-- Clone the repository from url to dest_dir
function clone(repository_url, dest_dir, depth, branch)

    assert(type(repository_url) == "string", "dist.git: Argument 'repository_url' is not a string.")

    local command = "git clone " .. repository_url

    if depth then
        assert(type(depth) == "number", "dist.git: Argument 'depth' is not a number.")
        command = command .. " --depth " .. depth
    end

    if branch then
        assert(type(branch) == "string", "dist.git: Argument 'branch' is not a string.")
        command = command .. " -b " .. branch
    end

    local ok = nil

    if dest_dir then
        assert(type(dest_dir) == "string", "dist.git: Argument 'dest_dir' is not a string.")
        command = command .. " " .. dest_dir

        if not sys.exists(dest_dir) then
            sys.make_dir(dest_dir)
        end

        -- change the current working directory to dest_dir
        local prev_current_dir = sys.current_dir()

        sys.change_dir(dest_dir)

        -- execute git clone
        ok = sys.exec(command)

        -- change the current working directory back
        sys.change_dir(prev_current_dir)
    else
        ok = sys.exec(command)
    end

    return ok
end
