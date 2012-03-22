-- main API of LuaDist

module ("dist", package.seeall)

local cfg = require "dist.config"
local depends = require "dist.depends"
local git = require "dist.git"
local sys = require "dist.sys"
local package = require "dist.package"
local mf = require "dist.manifest"

-- Return the deployment directory.
function get_deploy_dir()
    return sys.abs_path(cfg.root_dir)
end

-- Return packages deployed in 'deploy_dir' also with their provides.
function get_deployed(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.get_deployed: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    local deployed = depends.get_installed(deploy_dir)
    local provided = {}

    for _, pkg in pairs(deployed) do
        for _, provided_pkg in pairs(depends.get_provides(pkg)) do
            provided_pkg.provided_by = pkg.name .. "-" .. pkg.version
            table.insert(provided, provided_pkg)
        end
    end

    for _, provided_pkg in pairs(provided) do
        table.insert(deployed, provided_pkg)
    end

    deployed = depends.sort_by_names(deployed)
    return deployed
end

-- Download new 'manifest_file' from repository and returns it.
-- Return nil and error message on error.
function update_manifest(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.update_manifest: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    -- TODO: use 'deploy_dir' argument in manifest functions

    -- retrieve the new manifest (forcing no cache use)
    local manifest, err = mf.get_manifest(nil, true)

    if manifest then
        return manifest
    else
        return nil, err
    end
end

-- Install 'package_names' to 'deploy_dir', using optional CMake 'variables'.
-- If optional 'simulate' argument is true, the installation of packages will
-- be only simulated.
function install(package_names, deploy_dir, variables, simulate)
    if not package_names then return true end
    deploy_dir = deploy_dir or cfg.root_dir
    simulate = simulate or false
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")
    assert(type(simulate) == "boolean", "dist.install: Argument 'simulate' is not a boolean.")
    deploy_dir = sys.abs_path(deploy_dir)

    -- find installed packages
    local installed = depends.get_installed(deploy_dir)

    -- get manifest
    local manifest = mf.get_manifest()

    -- resolve dependencies
    local dependencies, err = depends.get_depends(package_names, installed, manifest)
    if err then return nil, err end
    if #dependencies == 0 then return nil, "No packages to install." end

    -- fetch the packages from repository
    local dirs, err = package.fetch_pkgs(dependencies, sys.make_path(deploy_dir, cfg.temp_dir))
    if not dirs then return nil, err end

    -- install fetched packages
    for _, dir in pairs(dirs) do
        ok, err = package.install_pkg(dir, deploy_dir, variables, false, simulate)
        if not ok then return nil, err end
    end

    -- XXX: delete directories created in dependency checks that weren't used in installation (?)

    return true
end

-- Manually deploy packages from 'package_paths' to 'deploy_dir', using optional
-- CMake 'variables'. The 'package_paths' are preserved (will not be deleted).
-- If optional 'simulate' argument is true, the deployment of packages will
-- be only simulated.
function make(deploy_dir, package_paths, variables, simulate)
    deploy_dir = deploy_dir or cfg.root_dir
    package_paths = package_paths or {}
    simulate = simulate or false

    assert(type(deploy_dir) == "string", "dist.make: Argument 'deploy_dir' is not a string.")
    assert(type(package_paths) == "table", "dist.make: Argument 'package_paths' is not a table.")
    assert(type(simulate) == "boolean", "dist.install: Argument 'simulate' is not a boolean.")
    deploy_dir = sys.abs_path(deploy_dir)

    local ok, err
    for _, path in pairs(package_paths) do
        ok, err = package.install_pkg(sys.abs_path(path), deploy_dir, variables, true, simulate)
        if not ok then return nil, err end
    end
    return ok
end

-- Remove 'package_names' from 'deploy_dir'
function remove(package_names, deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.remove: Argument 'package_names' is not a string or table.")
    assert(type(deploy_dir) == "string", "dist.remove: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    -- find packages to remove
    local pkgs_to_remove = depends.find_packages(package_names, depends.get_installed(deploy_dir))

    -- remove them
    for _, pkg in pairs(pkgs_to_remove) do
        local pkg_distinfo_dir = sys.make_path(cfg.distinfos_dir, pkg.name .. "-" .. pkg.version)
        local ok, err = package.remove_pkg(pkg_distinfo_dir, deploy_dir)
        if not ok then return nil, err end
    end

    return true
end

-- Download 'pkg_names' to 'fetch_dir'.
function fetch(pkg_names, fetch_dir)
    fetch_dir = fetch_dir or sys.current_dir()
    assert(type(pkg_names) == "table", "dist.fetch: Argument 'pkg_names' is not a string or table.")
    assert(type(fetch_dir) == "string", "dist.fetch: Argument 'fetch_dir' is not a string.")
    fetch_dir = sys.abs_path(fetch_dir)

    local manifest = mf.get_manifest()
    -- XXX: retrieve and check versions of packages

    local pkgs_to_fetch = {}

    for _, pkg_name in pairs(pkg_names) do
        local packages = depends.find_packages(pkg_name, manifest)
        if #packages == 0 then return nil, "No packages found for '" .. pkg_name .. "'." end

        packages = depends.sort_by_versions(packages)
        table.insert(pkgs_to_fetch, packages[1])
    end

    local ok, err = package.fetch_pkgs(pkgs_to_fetch, fetch_dir)

    if not ok then
        return nil, err
    else
        return ok
    end
end
