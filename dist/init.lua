-- Luadist API

module ("dist", package.seeall)

local git = require "dist.git"
local mf = require "dist.manifest"

-- Install package_names to deploy_dir
function install(package_names, deploy_dir)

    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")

    local manifest = mf.get_manifest()
end
