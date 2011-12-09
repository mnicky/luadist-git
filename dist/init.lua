-- main API of LuaDist

module ("dist", package.seeall)

local cfg = require "dist.config"
local dep = require "dist.depends"
local git = require "dist.git"
local sys = require "dist.sys"
local mf = require "dist.manifest"

-- Install package_names to deploy_dir
function install(package_names, deploy_dir)
    if not package_names then return true end

    deploy_dir = deploy_dir or cfg.root_dir
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")

    -- resolve dependencies
    local dependencies, err = dep.get_depends(package_names, deploy_dir)
    if err then return nil, err end

    -- TODO install packages after fetching all of them

    for _, pkg in pairs(dependencies) do

        -- TODO get tmp dir from configuration?
        -- fetch the package from git repository
        local ok, dir_or_err = fetch_pkg(pkg, deploy_dir .. "/tmp")

        if not ok then
            return nil, dir_or_err
        else
            ok, err = install_pkg(dir_or_err)
            if not ok then return nil, err end
        end
    end
end


-- Install package from 'pkg_dir' to 'deploy_dir'
function install_pkg(pkg_dir, deploy_dir)

    deploy_dir = deploy_dir or cfg.root_dir

    assert(type(pkg_dir) == "string", "dist.make_pkg: Argument 'pkg_dir' is not a string.")
    assert(type(deploy_dir) == "string", "dist.make_pkg: Argument 'deploy_dir' is not a string.")

    -- check for dist.info
    local info, err = mf.load_distinfo(pkg_dir .. "/dist.info")
    if not info then return nil, "Error installing '" .. pkg.name .. "-" .. pkg.version .. "': package in '" .. pkg_dir .. "' doesn't contain valid 'dist.info' file." end

    -- check if the package is source
    if sys.exists(pkg_dir .. "/CMakeLists.txt") then
        info.arch = info.arch or "Universal"
        info.type = info.type or "source"
    end

    -- check package's architecture
    if info.arch ~= "Universal" and info.arch ~= cfg.arch then
        return nil, "Error installing '" .. info.name .. "-" .. info.version .. "': architecture '" .. info.arch .. "' is not suitable for this machine."
    end

    -- check package's type
    if info.type ~= "all" and info.type ~= "source" and info.type ~= cfg.type then
        return nil, "Error installing '" .. info.name .. "-" .. info.version .. "': architecture type '" .. info.type .. "' is not suitable for this machine."
    end

    local ok, err

    -- if package is of source type, just deploy it
    if info.type ~= "source" then
        ok, err = deploy_pkg(pkg_dir, deploy_dir)
    -- else build the package
    else
        -- TODO implement build_pkg():
        -- ok, err = build_pkg(pkg_dir, deploy_dir)
        ok = true
    end

    -- delete directory of fetched package
    if not cfg.debug then sys.delete(pkg_dir) end

    return ok, err
end

-- Deploy package from 'pkg_dir' to 'deploy_dir' by copying
function deploy_pkg(pkg_dir, deploy_dir)

    deploy_dir = deploy_dir or cfg.root_dir

    assert(type(pkg_dir) == "string", "dist.deploy_pkg: Argument 'pkg_dir' is not a string.")
    assert(type(deploy_dir) == "string", "dist.deploy_pkg: Argument 'deploy_dir' is not a string.")

    -- check for dist.info
    local info, err = mf.load_distinfo(pkg_dir .. "/dist.info")
    if not info then return nil, "Error deploying package from '" .. pkg_dir .. "': it doesn't contain valid 'dist.info' file." end

    -- delete the 'dist.info' file
    sys.delete(pkg_dir .. "/dist.info")

    -- copy all files to the deploy_dir
    local ok, err = sys.copy(pkg_dir .. "/.", deploy_dir)
    if not ok then return nil, "Error deploying package '" .. info.name .. "-" .. info.version .. "': " .. err end

    -- save modified 'dist.info' file
    info.files = sys.get_file_list(pkg_dir)
    local pkg_distinfo_dir = deploy_dir .. "/" .. cfg.distinfos_dir .. "/" .. info.name .. "-" .. info.version
    sys.make_dir(pkg_distinfo_dir)

    ok, err = mf.save_distinfo(info, pkg_distinfo_dir .. "/dist.info")
    if not ok then return nil, err end

    return true, "Package '" .. info.name .. "-" .. info.version .. "' successfully deployed to '" .. deploy_dir .. "'."
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
        -- clean up
        sys.delete(clone_dir)
        return nil, "Error fetching package '" .. pkg.name .. "-" .. pkg.version .. "' from '" .. pkg.path .. "' to '" .. download_dir .. "'."
    end

    -- delete '.git' directory
    sys.delete(clone_dir .. "/" .. ".git")

    return ok, clone_dir
end



