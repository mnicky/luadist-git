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
    return cfg.root_dir
end

-- Return packages deployed in 'deploy_dir' also with their provides.
function get_deployed(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.get_deployed: Argument 'deploy_dir' is not a string.")

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

    table.sort(deployed, function (a,b) return a.name .. "-" .. a.version < b.name .. "-" .. b.version end)

    return deployed
end

-- Download new 'manifest_file' from repository and returns it.
-- Return nil and error message on error.
function update_manifest(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.update_manifest: Argument 'deploy_dir' is not a string.")

    -- make backup and delete the old manifest file
    if (sys.exists(deploy_dir .. "/" .. cfg.manifest_file)) then
        sys.copy(deploy_dir .. "/" .. cfg.manifest_file, deploy_dir .. "/" .. cfg.temp_dir)
    end
    sys.delete(deploy_dir .. "/" .. cfg.manifest_file)

    -- retrieve the new manifest
    local manifest, err = mf.get_manifest()

    -- if couldn't download new manifest then restore the backup and return error message
    if not manifest then
        sys.copy(deploy_dir .. "/" .. cfg.temp_dir .. "/" .. sys.extract_name(cfg.manifest_file), deploy_dir .. "/" .. cfg.cache_dir)
        sys.delete(deploy_dir .. "/" .. cfg.temp_dir .. "/" .. sys.extract_name(cfg.manifest_file))
        return nil, err
    -- else delete the backup and return the new manifest
    else
        sys.delete(deploy_dir .. "/" .. cfg.temp_dir .. "/" .. sys.extract_name(cfg.manifest_file))
        return manifest
    end
end

-- Install package_names to deploy_dir
function install(package_names, deploy_dir)
    if not package_names then return true end

    deploy_dir = deploy_dir or cfg.root_dir
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")

    -- find installed packages
    local installed = depends.get_installed(deploy_dir)

    -- get manifest
    local manifest = mf.get_manifest()

    -- resolve dependencies
    local dependencies, err = depends.get_depends(package_names, installed, manifest)
    if err then return nil, err end
    if #dependencies == 0 then return nil, "No packages to install." end

    -- fetch the packages from repository
    local dirs_or_err = {}
    local ok, dirs_or_err = package.fetch_pkgs(dependencies, deploy_dir .. "/" .. cfg.temp_dir)
    if not ok then return nil, dirs_or_err end

    -- install fetched packages
    for _, dir in pairs(dirs_or_err) do
        ok, err = package.install_pkg(dir, deploy_dir)
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

    -- find packages to remove
    local pkgs_to_remove = depends.find_packages(package_names, depends.get_installed(deploy_dir))

    -- remove them
    for _, pkg in pairs(pkgs_to_remove) do
        local pkg_distinfo_dir = cfg.distinfos_dir .. "/" .. pkg.name .. "-" .. pkg.version
        local ok, err = package.remove_pkg(pkg_distinfo_dir, deploy_dir)
        if not ok then return nil, err end
    end

    return true
end
