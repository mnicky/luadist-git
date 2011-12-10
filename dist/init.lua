-- main API of LuaDist

module ("dist", package.seeall)


local cfg = require "dist.config"
local dep = require "dist.depends"
local git = require "dist.git"
local sys = require "dist.sys"
local mf  = require "dist.manifest"

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

    -- TODO get tmp dir from configuration?

    -- fetch the packages from repository
    local dirs_or_err = {}
    local ok, dirs_or_err = fetch_pkgs(dependencies, deploy_dir .. "/tmp")
    if not ok then return nil, dirs_or_err end

    -- install fetched packages
    for _, dir in pairs(dirs_or_err) do
        ok, err = install_pkg(dir)
        if not ok then return nil, err end
    end

    return ok
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


-- Fetch packages (table 'packages') to 'download_dir'
-- Return if the operation was successful and a table of paths to the directories on success or an error message on error.
function fetch_pkgs(packages, download_dir)
    download_dir = download_dir or sys.current_dir()

    assert(type(packages) == "table", "dist.fetch_pkgs: Argument 'pkg' is not a table.")
    assert(type(download_dir) == "string", "dist.fetch_pkgs: Argument 'download_dir' is not a string.")

    local fetched_dirs = {}
    local ok, dir_or_err

    for _, pkg in pairs(packages) do
        ok, dir_or_err = fetch_pkg(pkg, download_dir)
        if not ok then
            return nil, dir_or_err
        else
            table.insert(fetched_dirs, dir_or_err)
        end
    end

    return ok, fetched_dirs
end

local fetch_pkg = fetch_pkg

-- Fetch packages (table 'packages') to 'download_dir' using 'max_parallel_downloads'
-- This function fetches packages in parallel using the lua 'lanes' module, so it must be available.
-- Return if the operation was successful and a table of paths to the directories on success or an error message on error.
function parallel_fetch_pkgs(packages, download_dir, max_parallel_downloads)
    download_dir = download_dir or sys.current_dir()
    max_parallel_downloads = max_parallel_downloads or 3

    assert(type(packages) == "table", "dist.parallel_fetch_pkgs: Argument 'pkg' is not a table.")
    assert(type(download_dir) == "string", "dist.parallel_fetch_pkgs: Argument 'download_dir' is not a string.")

    assert(pcall(require, "lanes"), "dist.parallel_fetch_pkgs: Module 'lanes' not found.")

    --local function fetch_pkg2 = fetch_pkg
    ------------------------------------------------------
    local function fetch_pkg2(pkg, download_dir)
        download_dir = download_dir or sys.current_dir()

        assert(type(pkg) == "table", "dist.fetch_pkg: Argument 'pkg' is not a table.")
        assert(type(download_dir) == "string", "dist.fetch_pkg: Argument 'download_dir' is not a string.")

        local repo_url = git.get_repo_url(pkg.path)
        local clone_dir = download_dir .. "/" .. pkg.name .. "-" .. pkg.version .. "-" .. pkg.arch .. "-" .. pkg.type

        local ok, err

        local quote = sys.quote

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
    ------------------------------------------------------

    local fetched_dirs = {}

    local fetching_thread = lanes.gen("os", "string", fetch_pkg2)
    local pkg_to_fetch = 1

    while pkg_to_fetch <= #packages do

        -- run threads to do parallel downloads
        local threads = {}
        while pkg_to_fetch <= #packages and #threads < max_parallel_downloads do
            table.insert(threads, fetching_thread(packages[pkg_to_fetch], download_dir))
            pkg_to_fetch = pkg_to_fetch + 1
        end

        -- join threads and get return values
        for t = 1, #threads do
            if not threads[t][1] then
                return nil, threads[t][2]
            else
                table.insert(fetched_dirs, threads[t][2])
            end
        end

    end

    return true, fetched_dirs
end
