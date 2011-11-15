-- Luadist API

module ("dist", package.seeall)

local git = require "dist.git"
local mf = require "dist.manifest"

-- Install package_names to deploy_dir
function install(package_names, deploy_dir)

    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")

    -- get manifest
    local manifest = mf.get_manifest()

    -- find matching packages
    local packages = find_packages(package_names)



end

-- Return packages from manifest
function find_packages(package_names, manifest)

    if type(package_names) == "string" then package_names = {package_names} end
    manifest = manifest or mf.get_manifest()

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(manifest) == "table", "dist.install: Argument 'manifest' is not a table.")

    local packages_found = {}

    -- find matching packages in manifest
    for k, pkg_to_install in pairs(package_names) do
        for k2, repo_pkg in pairs(manifest) do
            if repo_pkg.name == pkg_to_install then
                table.insert(packages_found, repo_pkg)
            end
        end
    end

    return packages_found
end
