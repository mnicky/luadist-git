-- Encapsulated Git functionality

module ("dist.git", package.seeall)

local sys = require "dist.sys"
local cfg = require "dist.config"


-- Clone the repository from url to dest_dir
function clone(repository_url, dest_dir, depth, branch)
    assert(type(repository_url) == "string", "git.clone: Argument 'repository_url' is not a string.")
    assert(type(dest_dir) == "string", "git.clone: Argument 'dest_dir' is not a string.")
    dest_dir = sys.abs_path(dest_dir)

    local command = "git clone " .. repository_url

    if depth then
        assert(type(depth) == "number", "git.clone: Argument 'depth' is not a number.")
        command = command .. " --depth " .. depth
    end

    if branch then
        assert(type(branch) == "string", "git.clone: Argument 'branch' is not a string.")
        command = command .. " -b " .. branch
    end

    command = command .. " " .. sys.quote(dest_dir)
    if sys.exists(dest_dir) then sys.delete(dest_dir) end
    sys.make_dir(dest_dir)

    -- change the current working directory to dest_dir
    local prev_current_dir = sys.current_dir()
    sys.change_dir(dest_dir)

    -- execute git clone
    if not cfg.debug then command = command .. " -q" end
    local ok, err = sys.exec(command)

    -- change the current working directory back
    sys.change_dir(prev_current_dir)

    return ok, err
end

-- Return git repository url from git url (used when old 'dist.manifest' format is present)
function get_repo_url(git_url)
    assert(type(git_url) == "string", "git.get_repo_path: Argument 'git_url' is not a string.")

    -- if it already is git repo url, just return it
    if git_url:sub(-4,-1) == ".git" then return git_url end

    local repo_start, repo_end = git_url:find("github.com/[^/]*/[^/]*")

    if repo_start ~= nil then
        return "https://" .. git_url:sub(repo_start, repo_end) .. ".git"
    else
        return nil, "Error getting git repository: not a valid git url: '" .. git_url .. "'."
    end
end

-- Return table of all refs of the remote repository at the 'git_url'. Ref_type can be 'tags' or 'heads'.
local function get_remote_refs(git_url, ref_type)
    assert(type(git_url) == "string", "git.get_remote_refs: Argument 'git_url' is not a string.")
    assert(type(ref_type) == "string", "git.get_remote_refs: Argument 'ref_type' is not a string.")

    local refs = {}
    local refstrings, err = sys.capture_output("git ls-remote --" .. ref_type .. " " .. git_url)
    if not refstrings then return nil, "Error getting refs of the remote repository '" .. git_url .. "': " .. err end

    for ref in refstrings:gmatch("/" .. ref_type .. "/(%S+)") do
        if not ref:match("%^{}") then table.insert(refs, ref) end
    end

    return refs
end

-- Return table of all tags of the repository at the 'git_url'
function get_remote_tags(git_url)
    return get_remote_refs(git_url, "tags")
end

-- Return table of all branches of the repository at the 'git_url'
function get_remote_branches(git_url)
    return get_remote_refs(git_url, "heads")
end

-- Checkout specified ref in specified git_repo_dir
function checkout_ref(ref, git_repo_dir, orphaned)
    git_repo_dir = git_repo_dir or sys.current_dir()
    orphaned = orphaned or false
    assert(type(ref) == "string", "git.checkout_ref: Argument 'ref' is not a string.")
    assert(type(git_repo_dir) == "string", "git.checkout_ref: Argument 'git_repo_dir' is not a string.")
    assert(type(orphaned) == "boolean", "git.checkout_ref: Argument 'orphaned' is not a boolean.")
    git_repo_dir = sys.abs_path(git_repo_dir)

    local command = "git checkout "
    if orphaned then command = command .. " --orphan " end
    command = command .. " " .. ref .. " -f"
    if not cfg.debug then command = command .. " -q" end

    local ok, err
    if git_repo_dir ~= sys.current_dir() then
        local prev_current_dir = sys.current_dir()
        sys.change_dir(git_repo_dir)
        ok, err = sys.exec(command)
        sys.change_dir(prev_current_dir)
    else
        ok, err = sys.exec(command)
    end

    return ok, err
end
