-- Luadist API

module ("dist", package.seeall)

local cfg = require "dist.config"
local dep = require "dist.depends"
local git = require "dist.git"

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
