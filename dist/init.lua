-- main API of LuaDist

module ("dist", package.seeall)

local cfg = require "dist.config"
local dep = require "dist.depends"
local git = require "dist.git"
local sys = require "dist.sys"

-- Install package_names to deploy_dir
function install(package_names, deploy_dir)
    if not package_names then return end

    deploy_dir = deploy_dir or cfg.root_dir
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")

    -- resolve dependencies
    local dependencies, err = dep.get_depends(package_names, deploy_dir)
    if err then return nil, err end

    for _, pkg in pairs(dependencies) do

        -- TODO get tmp dir from configuration?
        -- fetch the package from git repository
        fetch_pkg(pkg, deploy_dir .. "/tmp")



    end



end

-- Fetch package (table 'pkg') to download_dir
-- Return if the operation was successful and a path to the directory on success or an error message on error.
function fetch_pkg(pkg, download_dir)
    download_dir = download_dir or sys.current_dir()

    assert(type(pkg) == "table", "dist.fetch_pkg: Argument 'pkg' is not a table.")
    assert(type(download_dir) == "string", "dist.fetch_pkg: Argument 'download_dir' is not a string.")

    local repo_url = git.get_repo_url(pkg.path)
    local clone_dir = download_dir .. "/" .. pkg.name .. "-" .. pkg.version .. "-" .. pkg.arch .. "-" .. pkg.type

    local ok, err

    -- clone pkg's repository if it doesn't exist in download_dir
    if not sys.exists(clone_dir) then
        print("Getting " .. pkg.name .. "-" .. pkg.version .. "...")
        sys.make_dir(clone_dir)
        ok = git.clone(repo_url, clone_dir, 1)
    -- if clone_dir exists but doesn't contain dist.info, delete it and then clone the pkg
    elseif not sys.exists(clone_dir .. "/dist.info") then
        print("Getting " .. pkg.name .. "-" .. pkg.version .. "...")
        sys.delete(clone_dir)
        sys.make_dir(clone_dir)
        ok = git.clone(repo_url, clone_dir, 1)
    end

    -- checkout git tag according to the version of pkg
    if ok and pkg.version ~= "scm" then
        ok = git.checkout_tag(pkg.version, clone_dir)
    end

    if not ok then
        return nil, "Error fetching package '" .. pkg.name .. "-" .. pkg.version .. "' from '" .. pkg.path .. "' to '" .. download_dir .. "'."
    end

    -- delete '.git' directory
    sys.delete(clone_dir .. "/" .. ".git")

    return ok, clone_dir
end



