-- Luadist API

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
    local dependencies, err = dep.get_dependencies(package_names, deploy_dir)
    if err then
        return nil, err
    end

    for _, pkg in pairs(dependencies) do

        print(git.get_git_repo_url(pkg.path))

    end



end

-- Fetch package (table 'pkg') from git to download_dir
function fetch_pkg(pkg, download_dir)
    download_dir = download_dir or sys.current_dir()

    assert(type(pkg) == "table", "dist.fetch_pkg: Argument 'pkg' is not a table.")
    assert(type(download_dir) == "string", "dist.fetch_pkg: Argument 'download_dir' is not a string.")

    local repo_url = git.get_repo_url(pkg.path)
    local clone_dir = download_dir .. "/" .. pkg.name .. "-" .. pkg.version

    local ok = nil

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

    -- checkout particular tag (= version of pkg)
    if ok and pkg.version ~= "scm" then
        return git.checkout_tag(pkg.version, clone_dir)
    else
        return nil, "Error fetching package '" .. pkg.name .. "-" .. pkg.version "' from '" .. pkg.path .. "' to '" .. download_dir .. "'."
    end
end




