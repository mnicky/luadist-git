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

    if not sys.is_dir(distinfos_path) then return {} end

    -- from all directories of packages installed in deploy_dir
    for dir in sys.get_directory(distinfos_path) do
        if dir ~= "." and dir ~= ".." and sys.is_dir(distinfos_path .. "/" .. dir) then
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

-- TODO add arch & type checks

-- Return all packages needed in order to install 'package'
-- and with specified 'installed' packages in the system using 'manifest'.
-- Optional version 'constraint' can be added.
--
-- All returned packages (and their provides) are also inserted into the table 'installed'
--
-- 'dependency_parents' is table of all packages encountered so far when resolving dependencies
-- and is used to detect and deal with circular dependencies. Let it be 'nil'
-- and it will do its job just fine :-).

-- TODO change mutation of table 'installed' to returning it as a second return value
local function get_packages_to_install(package, installed, manifest, constraint, dependency_parents)

    manifest = manifest or mf.get_manifest()
    constraint = constraint or ""
    dependency_parents = dependency_parents or {}

    assert(type(package) == "string", "depends.get_packages_to_install: Argument 'package' is not a string.")
    assert(type(installed) == "table", "depends.get_packages_to_install: Argument 'installed' is not a table.")
    assert(type(manifest) == "table", "depends.get_packages_to_install: Argument 'manifest' is not a table.")
    assert(type(constraint) == "string", "depends.get_packages_to_install: Argument 'constraint' is not a string.")
    assert(type(dependency_parents) == "table", "depends.get_packages_to_install: Argument 'dependency_parents' is not a table.")

    -- table of packages needed to be installed (will be returned)
    local to_install = {}

    -- find candidates of packages wanted to install
    local candidates_to_install = find_packages(package, manifest)

    if #candidates_to_install == 0 then
        return nil, "No suitable candidate for package '" .. package .. (constraint or "") .. "' found."
    end

    -- filter candidates according to the constraint if provided
    if constraint ~= "" then
        candidates_to_install = filter_packages(candidates_to_install, constraint)
    end
    sort_by_versions(candidates_to_install)

    -- last occured error
    local err = nil

    -- whether pkg is already in installed table
    local pkg_is_installed = nil

    -- for all package candidates
    for k, pkg in pairs(candidates_to_install) do

        -- clear errors and installed state of previous candidate
        err = nil
        pkg_is_installed = false

        -- set required version if constraint specified
        if constraint ~= "" then
            pkg.version_wanted = constraint
        end

        -- remove this package from table
        candidates_to_install[k] = {}

        -- for all packages in table 'installed'
        for _, installed_pkg in pairs(installed) do

            -- check if pkg doesn't provide an already installed_pkg
            if pkg.provides then
                local was_err = false

                -- for all of pkg's provides
                for _, provided_pkg in pairs(get_provides(pkg)) do
                    if provided_pkg.name == installed_pkg.name then
                        err = "Package '" .. pkg.name .. "-" .. pkg.version .. "' provides '" .. provided_pkg.name .. (provided_pkg.version and "-" .. provided_pkg.version or "") .. "' but package '" .. installed_pkg.name .. (installed_pkg.version and "-" .. installed_pkg.version or "") .. "' is already installed."
                        was_err = true
                        break
                    end
                end
                if was_err then break end
            end


            -- check if pkg is in installed
            if not err and pkg.name == installed_pkg.name then

                -- if pkg was added due to some dependency, check if it's installed in satisfying version
                if not pkg.version_wanted or satisfies_constraint(installed_pkg.version, pkg.version_wanted) then
                    pkg_is_installed = true
                    break
                else
                    err = "Package '" .. pkg.name .. pkg.version_wanted .. "' needed as dependency, but installed at version '" .. installed_pkg.version .. "'."
                    break
                end
            end

            -- check for conflicts of package to install with installed package
            if not err and pkg.conflicts then
                for _, conflict in pairs (pkg.conflicts) do
                    if conflict == installed_pkg.name then
                        err = "Package '" .. pkg.name .. "-" .. pkg.version .. "' conflicts with installed package '" .. installed_pkg.name .. "-" .. installed_pkg.version .. "'."
                        break
                    end
                end
            end

            -- check for conflicts of installed package with package to install
            if not err and installed_pkg.conflicts then
                for _, conflict in pairs (installed_pkg.conflicts) do
                    if conflict == pkg.name then
                        err = "Installed package '" .. installed_pkg.name .. "-" .. installed_pkg.version .. "' conflicts with package '" .. pkg.name .. "-" .. pkg.version .. "'."
                        break
                    end
                end
            end
        end

        -- if pkg passed all of the above tests and isn't already installed
        if not err and not pkg_is_installed then

            -- check if pkg's dependencies are satisfied
            if pkg.depends then

                -- insert this pkg into the stack of circular dependencies detection
                table.insert(dependency_parents, pkg.name)

                -- for all dependencies of pkg
                for _, depend in pairs(pkg.depends) do

                    -- TODO add parsing of OS specific dependencies
                    -- something like:
                    --
                    -- ['depends'] = {
                    --               ['Linux'] = {
                    --                           [[unixodbc > 2.2]],
                    --                           }
                    --               }
                    --
                    -- (I didn't know about these until recently when I accidentally found one)
                    --
                    -- if type(depend) == "table" then
                    -- end

                    local dep_name, dep_constraint = split_name_constraint(depend)

                    -- detect circular dependencies using 'dependency_parents'
                    local is_circular_dependency = false
                    for _, parent in pairs(dependency_parents) do
                        if dep_name == parent then
                            is_circular_dependency = true
                            break
                        end
                    end

                    -- if circular dependencies not detected
                    if not is_circular_dependency then

                        -- recursively call this function on the candidates of this pkg's dependency
                        local depends_to_install, dep_err = get_packages_to_install(dep_name, installed, manifest, dep_constraint, dependency_parents)

                        -- if any suitable dependency packages were found, insert them to the 'to_install' table
                        if depends_to_install then
                            for _, depend_to_install in pairs(depends_to_install) do
                                table.insert(to_install, depend_to_install)
                            end
                        else
                            err = "Error getting dependency of '" .. pkg.name .. "-" .. pkg.version .. "': " .. dep_err
                            break
                        end

                    -- if circular dependencies detected
                    else
                        err = "Error getting dependency of '" .. pkg.name .. "-" .. pkg.version .. "': '" .. dep_name .. "' is a circular dependency."
                        break
                    end
                end

                -- remove last package from the stack of circular dependencies detection
                table.remove(dependency_parents)

            end

            -- if no error occured
            if not err then

                -- add pkg and it's provides to the fake table of installed packages
                table.insert(installed, pkg)
                if pkg.provides then
                    for _, provided_pkg in pairs(get_provides(pkg)) do
                        table.insert(installed, provided_pkg)
                    end
                end

                -- add pkg to the table of packages to install
                table.insert(to_install, pkg)

            -- if any error occured
            else

                -- clear tables of installed packages and packages to install to the original state
                to_install = {}
                installed = get_installed(deploy_dir)

                -- add provided packages to installed ones
                for _, installed_pkg in pairs(installed) do
                    for _, pkg in pairs(get_provides(installed_pkg)) do
                        table.insert(installed, pkg)
                    end
                end
            end

        end
    end

    -- if package is not installed and no suitable candidates to be installed were found, return the last error
    if #to_install == 0 and not pkg_is_installed then
        return nil, err
    else
        return to_install
    end
end

-- Resolve dependencies and return all packages needed in order to install
-- 'packages' into 'installed' ones, using 'manifest'.
function get_depends(packages, installed, manifest)
    if not packages then return {} end

    manifest = manifest or mf.get_manifest()

    if type(packages) == "string" then packages = {packages} end
    if type(installed) == "string" then installed = {installed} end

    assert(type(packages) == "table", "depends.get_dependencies: Argument 'packages' is not a table or string.")
    assert(type(installed) == "table", "depends.get_dependencies: Argument 'installed' is not a table or string.")
    assert(type(manifest) == "table", "depends.get_dependencies: Argument 'manifest' is not a table.")

    -- add provided packages to installed ones
    for _, installed_pkg in pairs(installed) do
        for _, pkg in pairs(get_provides(installed_pkg)) do
            table.insert(installed, pkg)
        end
    end

    local to_install = {}

    -- get packages needed to to satisfy dependencies
    for _, pkg in pairs(packages) do
        local needed_to_install, err = get_packages_to_install(pkg, installed, manifest)

        if needed_to_install then
            for _, needed_pkg in pairs(needed_to_install) do
                table.insert(to_install, needed_pkg)
            end
        else
            return nil, "Cannot install package '" .. pkg .. "': ".. err
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
