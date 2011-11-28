-- Encapsulated Git functionality

module ("dist.git", package.seeall)

local sys = require "dist.sys"


-- Clone the repository from url to dest_dir
function clone(repository_url, dest_dir, depth, branch)

    assert(type(repository_url) == "string", "git.clone: Argument 'repository_url' is not a string.")

    local command = "git clone " .. repository_url

    if depth then
        assert(type(depth) == "number", "git.clone: Argument 'depth' is not a number.")
        command = command .. " --depth " .. depth
    end

    if branch then
        assert(type(branch) == "string", "git.clone: Argument 'branch' is not a string.")
        command = command .. " -b " .. branch
    end

    local ok = nil

    if dest_dir then
        assert(type(dest_dir) == "string", "git.clone: Argument 'dest_dir' is not a string.")
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

-- Return git repository url from git url (used when old 'dist.manifest' format is present)
function get_repo_url(git_url)
    assert(type(git_url) == "string", "git.get_repo_path: Argument 'git_url' is not a string.")

    local repo_start, repo_end = git_url:find("github.com/[^/]*/[^/]*")

    if repo_start ~= nil then
        return "https://" .. git_url:sub(repo_start, repo_end) .. ".git"
    else
        return nil, "Error getting git repository: not a valid git url: '" .. git_url .. "'."
    end
end

-- Checkout specified tag in specified git_repo_dir
function checkout_tag(tag, git_repo_dir)

    git_repo_dir = git_repo_dir or sys.current_dir()

    assert(type(tag) == "string", "git.checkout_tag: Argument 'tag' is not a string.")
    assert(type(git_repo_dir) == "string", "git.checkout_tag: Argument 'git_repo_dir' is not a string.")

    local command = "git checkout " .. tag

    if git_repo_dir ~= sys.current_dir() then
        local prev_current_dir = sys.current_dir()
        sys.change_dir(git_repo_dir)

        ok = sys.exec(command)

        sys.change_dir(prev_current_dir)
    else
        ok = sys.exec(command)
    end

    return ok
end
