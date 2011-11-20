-- Utility functions for dependencies

module ("dist.depends", package.seeall)

local cfg = require "dist.config"
local mf = require "dist.manifest"
local sys = require "dist.sys"
local const = require "dist.constraints"

-- Return all packages with specified names from manifest
function find_packages(package_names, manifest)

    if type(package_names) == "string" then package_names = {package_names} end
    manifest = manifest or mf.get_manifest()

    assert(type(package_names) == "table", "depends.find_packages: Argument 'package_names' is not a table or string.")
    assert(type(manifest) == "table", "depends.find_packages: Argument 'manifest' is not a table.")

    local packages_found = {}

    -- TODO reporting when no candidate for some package is found ??

    -- find matching packages in manifest
    for _, pkg_to_find in pairs(package_names) do
        for _, repo_pkg in pairs(manifest) do
            if repo_pkg.name == pkg_to_find then
                table.insert(packages_found, repo_pkg)
            end
        end
    end

    return packages_found
end

-- Return manifest consisting of packages installed in specified deploy_dir directory
function get_installed(deploy_dir)

    deploy_dir = deploy_dir or cfg.root_dir

    assert(type(deploy_dir) == "string", "depends.get_installed: Argument 'deploy_dir' is not a string.")

    local distinfos_path = deploy_dir .. "/" .. cfg.distinfos_dir
    local manifest = {}

    -- from all directories of packages installed in deploy_dir
    for dir in sys.get_directory(distinfos_path) do
        if sys.is_dir(distinfos_path .. "/" .. dir) then
            -- load the dist.info file
            for file in sys.get_directory(distinfos_path .. "/" .. dir) do
                if sys.is_file(distinfos_path .. "/" .. dir .. "/" .. file) then
                    table.insert(manifest, mf.load_distinfo(distinfos_path .. "/" .. dir .. "/" .. file))
                end
            end

        end
    end

    return manifest
end


-- TODO: If dependencies of one candidate fail, check another candidate
-- TODO add ability to specify version constraints?

-- Resolve dependencies and return all packages needed in order to install 'packages' into 'deploy_dir'
function get_dependencies(packages, deploy_dir)
    if not packages then return {} end

    deploy_dir = deploy_dir or cfg.root_dir
    if type(packages) == "string" then packages = {packages} end

    assert(type(packages) == "table", "depends.get_dependencies: Argument 'packages' is not a table or string.")
    assert(type(deploy_dir) == "string", "depends.get_dependencies: Argument 'deploy_dir' is not a string.")

    -- get manifest
    local manifest = mf.get_manifest()

    -- find matching packages
    local want_to_install = find_packages(packages, manifest)
    sort_by_versions(want_to_install)

    -- find installed packages
    local installed = get_installed(deploy_dir)

    -- add provided packages to installed ones
    for _, installed_pkg in pairs(installed) do
        for _, pkg in pairs(get_provides(installed_pkg)) do
            table.insert(installed, pkg)
        end
    end

    -- table of packages needed to install (will be returned)
    local to_install = {}

    -- for all packages wanted to install
    for k, pkg in pairs(want_to_install) do

        -- remove this package from table
        want_to_install[k] = {}

        -- whether pkg is already in installed table
        local pkg_is_installed = false

        -- for all packages in table 'installed'
        for _, installed_pkg in pairs(installed) do

            -- check if pkg is in installed
            if pkg.name == installed_pkg.name then

                -- if pkg was added due to some dependency, check if it's installed in satisfying version
                if not pkg.version_wanted or satisfies_constraint(installed_pkg.version, pkg.version_wanted) then
                    pkg_is_installed = true
                    break
                else
                    return nil, "Package '" .. pkg.name .. pkg.version_wanted .. "' needed as dependency, but installed at version '" .. installed_pkg.version .. "'."
                end
            end

            -- check for conflicts of package to install with installed package
            if pkg.conflicts then
                for _, conflict in pairs (pkg.conflicts) do
                    if conflict == installed_pkg.name then
                        return nil, "Package '" .. pkg.name .. "' conflicts with installed package '" .. installed_pkg.name .. "'."
                    end
                end
            end

            -- check for conflicts of installed package with package to install
            if installed_pkg.conflicts then
                for _, conflict in pairs (installed_pkg.conflicts) do
                    if conflict == pkg.name then
                        return nil, "Installed package '" .. installed_pkg.name .. "' conflicts with package'" .. pkg.name .. "'."
                    end
                end
            end
        end

        -- if pkg's not in installed and passed all of the above tests
        if not pkg_is_installed then

            -- check if pkg's dependencies are satisfied
            if pkg.depends then

                -- for all dependencies of pkg
                for _, depend in pairs(pkg.depends) do
                    local dep_name, dep_constraint = split_name_constraint(depend)

                    -- if satisfying version of this dependency is installed, skip to the next one
                    for _, installed_pkg in pairs(installed) do
                        if installed_pkg.name == dep_name and satisfies_constraint(installed_pkg.version, dep_constraint) then
                            break
                        end
                    end

                    -- find candidates to pkg's dependencies
                    local depend_candidates = find_packages(dep_name, manifest)

                    -- filter candidates according to the constraint and sort them by versions
                    depend_candidates = filter_packages(depend_candidates, dep_constraint)
                    sort_by_versions(depend_candidates)

                    -- collect suitable candidates for this pkg's dependency
                    if depend_candidates and #depend_candidates > 0 then
                        for _, depend_candidate in pairs(depend_candidates) do

                            -- remember the required version for checking the installed versions of this dependency
                            depend_candidate.version_wanted = dep_constraint
                            -- add them to the table of packages wanted to install
                            table.insert(want_to_install, depend_candidate)
                        end
                    else
                        return nil, "No suitable candidate for dependency '" .. dep_name .. dep_constraint .. "' of package '" .. pkg.name .."' found."
                    end
                end
            end

            -- add pkg and it's provides to the fake table of installed packages
            table.insert(installed, pkg)
            if pkg.provides then
                for _, provided_pkg in pairs(get_provides(pkg)) do
                    table.insert(installed, provided_pkg)
                end
            end

            -- add pkg to the table of packages to install
            table.insert(to_install, pkg)
        end
    end

    return to_install
end

-- Return table of packages provided by specified package (from it's 'provides' field)
function get_provides(package)
    assert(type(package) == "table", "depends.get_provides: Argument 'package' is not a table.")

    if not package.provides then return {} end

    local provided = {}

    for _, provided_name in pairs(package.provides) do
        local pkg = {}
        pkg.name, pkg.version = split_name_constraint(provided_name)
        pkg.type = package.type
        pkg.arch = package.arch
        pkg.provided = package.name .. "-" .. package.version
        table.insert(provided, pkg)
    end

    return provided
end

-- Return package name and version constraint from full package version constraint specification
-- E. g.:
--          for 'luaexpat-1.2.3'  return:  'luaexpat' , '1.2.3'
--          for 'luajit >= 1.2'   return:  'luajit'   , '>=1.2'
function split_name_constraint(version_constraint)
    assert(type(version_constraint) == "string", "depends.split_name_constraint: Argument 'version_constraint' is not a string.")

    local split = version_constraint:find("[%s=~<>-]+%d") or version_constraint:find("[%s=~<>-]+scm")

    if split then
        return version_constraint:sub(1, split - 1), version_constraint:sub(split):gsub("[%s-]", "")
    else
        return version_constraint, nil
    end
end

-- Return only packages that satisfy specified constraint
function filter_packages(packages, constraint)

    if type(packages) == "string" then packages = {packages} end

    assert(type(packages) == "table", "depends.filter_packages: Argument 'packages' is not a string or table.")
    assert(type(constraint) == "string", "depends.filter_packages: Argument 'constraint' is not a string.")

    local passed_pkgs = {}

    for _, pkg in pairs(packages) do
        if satisfies_constraint(pkg.version, constraint) then
            table.insert(passed_pkgs, pkg)
        end
    end

    return passed_pkgs
end

-- Sort table of packages descendingly by versions (newer ones are moved to the top).
function sort_by_versions(packages)
    assert(type(packages) == "table", "depends.sort_by_versions: Argument 'packages' is not a string or table.")

    table.sort(packages, function (a,b) return compare_versions(a.version, b.version) end)
end

-- Return if version satisfies the specified constraint
function satisfies_constraint(version, constraint)
    assert(type(version) == "string", "depends.satisfies_constraint: Argument 'version' is not a string.")
    assert(type(constraint) == "string", "depends.satisfies_constraint: Argument 'constraint' is not a string.")

    return const.constraint_satisfied(version, constraint)
end

-- Return for package versions if: 'version_a' > 'version_b'
function compare_versions(version_a, version_b)
    assert(type(version_a) == "string", "depends.compare_versions: Argument 'version_a' is not a string.")
    assert(type(version_b) == "string", "depends.compare_versions: Argument 'version_b' is not a string.")

    return const.compareVersions(version_a,version_b)
end
