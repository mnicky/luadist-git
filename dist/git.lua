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
    if not cfg.debug then command = command .. " -q " end
    local ok, err = sys.exec(command)

    -- change the current working directory back
    sys.change_dir(prev_current_dir)

    return ok, err
end

-- Return table of all refs of the remote repository at the 'git_url'. Ref_type can be "tags" or "heads".
local function get_remote_refs(git_url, ref_type)
    assert(type(git_url) == "string", "git.get_remote_refs: Argument 'git_url' is not a string.")
    assert(type(ref_type) == "string", "git.get_remote_refs: Argument 'ref_type' is not a string.")
    assert(ref_type == "tags" or ref_type == "heads", "git.get_remote_refs: Argument 'ref_type' is not \"tags\" or \"heads\".")

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
    if not cfg.debug then command = command .. " -q " end

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

-- Create an empty git repository in given directory.
function init(dir)
    dir = dir or sys.current_dir()
    assert(type(dir) == "string", "git.init: Argument 'dir' is not a string.")
    dir = sys.abs_path(dir)

    -- create the 'dir' first, since it causes 'git init' to fail on Windows
    -- when the parent directory of 'dir' doesn't exist
    local ok, err = sys.make_dir(dir)
    if not ok then return nil, err end

    local command = "git init " .. dir
    if not cfg.debug then command = command .. " -q " end
    return sys.exec(command)
end

-- Add all files in the 'repo_dir' to the git index. The 'repo_dir' must be
-- in the initialized git repository.
function add_all(repo_dir)
    repo_dir = repo_dir or sys.current_dir()
    assert(type(repo_dir) == "string", "git.add_all: Argument 'repo_dir' is not a string.")
    repo_dir = sys.abs_path(repo_dir)

    local ok, prev_dir, msg
    ok, prev_dir = sys.change_dir(repo_dir);
    if not ok then return nil, err end

    ok, msg = sys.exec("git add -A " .. repo_dir)
    sys.change_dir(prev_dir)

    return ok, msg
end

-- Commit all indexed files in 'repo_dir' with the given commit 'message'.
-- The 'repo_dir' must be in the initialized git repository.
function commit(message, repo_dir)
    repo_dir = repo_dir or sys.current_dir()
    message = message or "commit by luadist-git"
    message = sys.quote(message)
    assert(type(message) == "string", "git.commit: Argument 'message' is not a string.")
    assert(type(repo_dir) == "string", "git.commit: Argument 'repo_dir' is not a string.")
    repo_dir = sys.abs_path(repo_dir)

    local ok, prev_dir, msg
    ok, prev_dir = sys.change_dir(repo_dir);
    if not ok then return nil, err end

    local command = "git commit -m " .. message
    if not cfg.debug then command = command .. " -q " end
    ok, msg = sys.exec(command)
    sys.change_dir(prev_dir)

    return ok, msg
end


-- Rename branch 'old_name' to 'new_name'. -- The 'repo_dir' must be
-- in the initialized git repository and the branch 'new_name' must
-- not already exist in that repository.
function rename_branch(old_name, new_name, repo_dir)
    repo_dir = repo_dir or sys.current_dir()
    assert(type(old_name) == "string", "git.rename_branch: Argument 'old_name' is not a string.")
    assert(type(new_name) == "string", "git.rename_branch: Argument 'new_name' is not a string.")
    assert(type(repo_dir) == "string", "git.rename_branch: Argument 'repo_dir' is not a string.")
    repo_dir = sys.abs_path(repo_dir)

    local ok, prev_dir, msg
    ok, prev_dir = sys.change_dir(repo_dir);
    if not ok then return nil, err end

    ok, msg = sys.exec("git branch -m " .. old_name .. " " .. new_name)
    sys.change_dir(prev_dir)

    return ok, msg
end

-- Push the ref 'ref_name' from the 'repo_dir' to the remote git
-- repository 'git_repo_url'. If 'all_tags' is set to true, all tags
-- will be pushed, in addition to the explicitly given ref.
-- If 'delete' is set to 'true' then the explicitly given remote ref
-- will be deleted, not pushed.
function push_ref(repo_dir, ref_name, git_repo_url, all_tags, delete)
    repo_dir = repo_dir or sys.current_dir()
    all_tags = all_tags or false
    delete = delete or false
    assert(type(repo_dir) == "string", "git.push_ref: Argument 'repo_dir' is not a string.")
    assert(type(git_repo_url) == "string", "git.push_ref: Argument 'git_repo_url' is not a string.")
    assert(type(ref_name) == "string", "git.push_ref: Argument 'ref_name' is not a string.")
    assert(type(all_tags) == "boolean", "git.push_ref: Argument 'all_tags' is not a boolean.")
    assert(type(delete) == "boolean", "git.push_ref: Argument 'delete' is not a boolean.")
    repo_dir = sys.abs_path(repo_dir)

    local ok, prev_dir, msg
    ok, prev_dir = sys.change_dir(repo_dir);
    if not ok then return nil, err end

    local command = "git push " .. git_repo_url
    if all_tags then command = command .. " --tags " end
    if delete then command = command .. " --delete " end
    command = command .. " " .. ref_name .. " -f "
    if not cfg.debug then command = command .. " -q " end

    ok, msg = sys.exec(command)
    sys.change_dir(prev_dir)

    return ok, msg
end

-- Creates the tag 'tag_name' in given 'repo_dir', which must be
-- in the initialized git repository
function create_tag(repo_dir, tag_name)
    repo_dir = repo_dir or sys.current_dir()
    assert(type(repo_dir) == "string", "git.create_tag: Argument 'repo_dir' is not a string.")
    assert(type(tag_name) == "string", "git.create_tag: Argument 'tag_name' is not a string.")
    repo_dir = sys.abs_path(repo_dir)

    local ok, prev_dir, msg
    ok, prev_dir = sys.change_dir(repo_dir);
    if not ok then return nil, err end

    ok, msg = sys.exec("git tag " .. tag_name .. " -f ")
    sys.change_dir(prev_dir)

    return ok, msg
end

-- Fetch given 'ref_name' from the remote 'git_repo_url' to the local repository
-- 'repo_dir' and save it as a ref with the same 'ref_name' and 'ref_type'.
-- 'ref_type' can be "tag" or "head".
local function fetch_ref(repo_dir, git_repo_url, ref_name, ref_type)
    repo_dir = repo_dir or sys.current_dir()
    assert(type(repo_dir) == "string", "git.fetch_ref: Argument 'repo_dir' is not a string.")
    assert(type(git_repo_url) == "string", "git.fetch_ref: Argument 'git_repo_url' is not a string.")
    assert(type(ref_name) == "string", "git.fetch_ref: Argument 'ref_name' is not a string.")
    assert(type(ref_type) == "string", "git.fetch_ref: Argument 'ref_type' is not a string.")
    assert(ref_type == "tag" or ref_type == "head", "git.get_remote_refs: Argument 'ref_type' is not \"tag\" or \"head\".")
    repo_dir = sys.abs_path(repo_dir)

    local ok, prev_dir, msg
    ok, prev_dir = sys.change_dir(repo_dir);
    if not ok then return nil, err end

    local command = "git fetch -f -u " .. git_repo_url .. " "

    if ref_type == 'tag' then
        command = command .. " +refs/tags/" .. ref_name .. ":refs/tags/" .. ref_name
    elseif ref_type == 'head' then
        command = command .. " +refs/heads/" .. ref_name .. ":" .. ref_name
    end
    if not cfg.debug then command = command .. " -q " end

    ok, msg = sys.exec(command)
    sys.change_dir(prev_dir)
    return ok, msg
end

-- Fetch given 'tag_name' from the remote 'git_repo_url' to the local repository
-- 'repo_dir' and save it as a tag with the same 'tag_name'.
function fetch_tag(repo_dir, git_repo_url, tag_name)
    return fetch_ref(repo_dir, git_repo_url, tag_name, "tag")
end

-- Fetch given 'branch_name' from the remote 'git_repo_url' to the local repository
-- 'repo_dir' and save it as a branch with the same 'branch_name'.
function fetch_branch(repo_dir, git_repo_url, branch_name)
    return fetch_ref(repo_dir, git_repo_url, branch_name, "head")
end
