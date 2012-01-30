-- Utility functions for dependencies

module ("dist.depends", package.seeall)

local cfg = require "dist.config"
local mf = require "dist.manifest"
local sys = require "dist.sys"
local const = require "dist.constraints"
local utils = require "dist.utils"

-- Return all packages with specified names from manifest.
-- Names can also contain version constraint (e.g. 'copas>=1.2.3', 'saci-1.0' etc.).
function find_packages(package_names, manifest)
    if type(package_names) == "string" then package_names = {package_names} end
    manifest = manifest or mf.get_manifest()

    assert(type(package_names) == "table", "depends.find_packages: Argument 'package_names' is not a table or string.")
    assert(type(manifest) == "table", "depends.find_packages: Argument 'manifest' is not a table.")

    local packages_found = {}
    -- find matching packages in manifest
    for _, pkg_to_find in pairs(package_names) do
        local pkg_name, pkg_constraint = split_name_constraint(pkg_to_find)
        for _, repo_pkg in pairs(manifest) do
            if repo_pkg.name == pkg_name and (not pkg_constraint or satisfies_constraint(repo_pkg.version, pkg_constraint)) then
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

-- Return whether the 'package_name' is installed according to the the manifest 'installed_pkgs'
-- If optional 'version_wanted' constraint is specified, then installed packages must
-- also satisfy specified version constraint.
-- If package is installed but doesn't satisfy version constraint, error message
-- is returned as the second value.
local function is_installed(package_name, installed_pkgs, version_wanted)
    assert(type(package_name) == "string", "depends.is_installed: Argument 'package_name' is not a string.")
    assert(type(installed_pkgs) == "table", "depends.is_installed: Argument 'installed_pkgs' is not a table.")
    assert(type(version_wanted) == "string" or type(version_wanted) == "nil", "depends.is_installed: Argument 'version_wanted' is not a string or nil.")

    local pkg_is_installed, err = false, nil

    for _, installed_pkg in pairs(installed_pkgs) do

        -- check if package_name is in installed
        if package_name == installed_pkg.name then

            -- check if package is installed in satisfying version
            if not version_wanted or satisfies_constraint(installed_pkg.version, version_wanted) then
                pkg_is_installed = true
                break
            else
                err = "Package '" .. package_name .. (version_wanted and " " .. version_wanted or "") .. "' needed, but installed at version '" .. installed_pkg.version .. "'."
                break
            end
        end

    end
    return pkg_is_installed, err
end

-- Check whether the package 'pkg' conflicts with 'installed_pkg' and return
-- false or error message.
local function packages_conflicts(pkg, installed_pkg)

    -- If 'pkg.selected' == true then returns 'selected' else 'installed'.
    -- Used in error messages.
    local function selected_or_installed(pkg)
        assert(type(pkg) == "table", "depends.packages_conflicts.selected_or_installed: Argument 'pkg' is not a table.")
        if pkg.selected == true then
            return "selected"
        else
            return "installed"
        end
    end

    -- check if pkg doesn't provide an already installed_pkg
    if pkg.provides then
        -- for all of pkg's provides
        for _, provided_pkg in pairs(get_provides(pkg)) do
            if provided_pkg.name == installed_pkg.name then
                return "Package '" .. pkg_full_name(pkg.name, pkg.version) .. "' provides '" .. pkg_full_name(provided_pkg.name, provided_pkg.version) .. "' but package '" .. pkg_full_name(installed_pkg.name, installed_pkg.version) .. "' is already " .. selected_or_installed(installed_pkg) .. "."
            end
        end
    end

    -- check for conflicts of package to install with installed package
    if pkg.conflicts then
        for _, conflict in pairs (pkg.conflicts) do
            if conflict == installed_pkg.name then
                return "Package '" .. pkg_full_name(pkg.name, pkg.version) .. "' conflicts with already " .. selected_or_installed(installed_pkg) .. " package '" .. pkg_full_name(installed_pkg.name, installed_pkg.version) .. "'."
            end
        end
    end

    -- check for conflicts of installed package with package to install
    if installed_pkg.conflicts then

        -- direct conflicts with 'pkg'
        for _, conflict in pairs (installed_pkg.conflicts) do
            if conflict == pkg.name then
                return "Already " .. selected_or_installed(installed_pkg) .. " package '" .. pkg_full_name(installed_pkg.name, installed_pkg.version) .. "' conflicts with package '" .. pkg_full_name(pkg.name, pkg.version) .. "'."
            end
        end

        -- conflicts with 'provides' of 'pkg' (packages provided by package to install)
        if pkg.provides then
            for _, conflict in pairs (installed_pkg.conflicts) do
                -- for all of pkg's provides
                for _, provided_pkg in pairs(get_provides(pkg)) do
                    if conflict == provided_pkg.name then
                        return "Already '" .. selected_or_installed(installed_pkg) .. " package '" .. pkg_full_name(installed_pkg.name, installed_pkg.version) .. "' conflicts with package '" .. pkg_full_name(provided_pkg.name, provided_pkg.version) .. "' provided by '" .. pkg_full_name(pkg.name, pkg.version) .. "'."
                    end
                end
            end
        end
    end

    -- no conflicts found
    return false
end

-- Return all packages needed in order to install 'package'
-- and with specified 'installed' packages in the system using 'manifest'.
-- 'package' can also contain version constraint (e.g. 'copas>=1.2.3', 'saci-1.0' etc.).
--
-- All returned packages (and their provides) are also inserted into the table 'installed'
--
-- 'dependency_parents' is table of all packages encountered so far when resolving dependencies
-- and is used to detect and deal with circular dependencies. Leave it 'nil'
-- and it will do its job just fine :-).
--
-- 'tmp_installed' is internal table used in recursion and should be left 'nil' when
-- calling this function from other context. It is used for passing the changes
-- in installed packages between the recursive calls of this function.
--
-- TODO: refactor this spaghetti code!
local function get_packages_to_install(package, installed, manifest, dependency_parents, tmp_installed)
    manifest = manifest or mf.get_manifest()
    dependency_parents = dependency_parents or {}

    -- set helper table 'tmp_installed'
    tmp_installed = tmp_installed or utils.deepcopy(installed)

    assert(type(package) == "string", "depends.get_packages_to_install: Argument 'package' is not a string.")
    assert(type(installed) == "table", "depends.get_packages_to_install: Argument 'installed' is not a table.")
    assert(type(manifest) == "table", "depends.get_packages_to_install: Argument 'manifest' is not a table.")
    assert(type(dependency_parents) == "table", "depends.get_packages_to_install: Argument 'dependency_parents' is not a table.")
    assert(type(tmp_installed) == "table", "depends.get_packages_to_install: Argument 'tmp_installed' is not a table.")

    -- check if package is already installed
    local pkg_name, pkg_constraint = split_name_constraint(package)
    local pkg_is_installed, err = is_installed(pkg_name, tmp_installed, pkg_constraint)
    if pkg_is_installed then return {} end
    if err then return nil, err end

    -- table of packages needed to be installed (will be returned)
    local to_install = {}

    -- find candidates & filter them
    local candidates_to_install = find_packages(package, manifest)
    candidates_to_install = filter_packages_by_arch_and_type(candidates_to_install, cfg.arch, cfg.type)

    if #candidates_to_install == 0 then
        return nil, "No suitable candidate for package '" .. package .. "' found."
    end

    sort_by_versions(candidates_to_install)

    for k, pkg in pairs(candidates_to_install) do

        -- clear the state from previous candidate
        pkg_is_installed, err = false, nil

        -- check whether this package has already been added to 'tmp_installed' by another of its candidates
        pkg_is_installed, err = is_installed(pkg.name, tmp_installed, pkg_constraint)
        if pkg_is_installed then break end

        -- checks for conflicts with other installed (or previously selected) packages
        if not err then
            for _, installed_pkg in pairs(tmp_installed) do
                err = packages_conflicts(pkg, installed_pkg)
                if err then break end
            end
        end

        -- if pkg passed all of the above tests and isn't already installed
        if not err and not pkg_is_installed then

            -- check if pkg's dependencies are satisfied
            if pkg.depends then

                -- insert pkg into the stack of circular dependencies detection
                table.insert(dependency_parents, pkg.name)

                -- collect all OS specific dependencies of pkg
                for k, depend in pairs(pkg.depends) do

                    -- if 'depend' is a table of OS specific dependencies for
                    -- this arch, add them to the normal dependencies of pkg
                    if type(depend) == "table" then
                        if k == cfg.arch then
                            for _, os_specific_depend in pairs(depend) do
                                table.insert(pkg.depends, os_specific_depend)
                            end
                        end
                    end
                end

                -- for all dependencies of pkg
                for _, depend in pairs(pkg.depends) do

                    -- skip tables of OS specific dependencies
                    if type(depend) ~= "table" then
                        local dep_name = split_name_constraint(depend)

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
                            local depends_to_install, dep_err = get_packages_to_install(depend, installed, manifest, dependency_parents, tmp_installed)

                            -- if any suitable dependency packages were found, insert them to the 'to_install' table
                            if depends_to_install then
                                for _, depend_to_install in pairs(depends_to_install) do
                                    table.insert(to_install, depend_to_install)
                                end
                            else
                                err = "Error getting dependency of '" .. pkg_full_name(pkg.name, pkg.version) .. "': " .. dep_err
                                break
                            end

                        -- if circular dependencies detected
                        else
                            err = "Error getting dependency of '" .. pkg_full_name(pkg.name, pkg.version) .. "': '" .. dep_name .. "' is a circular dependency."
                            break
                        end

                    end
                end

                -- remove last package from the stack of circular dependencies detection
                table.remove(dependency_parents)
            end

            -- if no error occured
            if not err then
                -- add pkg and it's provides to the fake table of installed packages, with
                -- property 'selected' set, indicating that the package isn't
                -- really installed in the system, just selected to be installed (used e.g. in error messages)
                pkg.selected = true
                table.insert(tmp_installed, pkg)
                if pkg.provides then
                    for _, provided_pkg in pairs(get_provides(pkg)) do
                        provided_pkg.selected = true
                        table.insert(tmp_installed, provided_pkg)
                    end
                end
                -- add pkg to the table of packages to install
                table.insert(to_install, pkg)

            -- if some error occured
            else
                -- set tables of 'packages to install' and 'installed packages' to their original state
                to_install = {}
                tmp_installed = utils.deepcopy(installed)

                -- add provided packages to installed ones
                for _, installed_pkg in pairs(tmp_installed) do
                    for _, pkg in pairs(get_provides(installed_pkg)) do
                        table.insert(tmp_installed, pkg)
                    end
                end
            end

        -- if pkg is already installed, skip checking its other candidates
        elseif pkg_is_installed then
            break
        end
    end

    -- if package is not installed and no suitable candidates were found, return the last error
    if #to_install == 0 and not pkg_is_installed then
        return nil, err
    else
        return to_install
    end
end

-- Resolve dependencies and return all packages needed in order to install
-- 'packages' into the system with already 'installed' packages, using 'manifest'.
function get_depends(packages, installed, manifest)
    if not packages then return {} end

    manifest = manifest or mf.get_manifest()
    if type(packages) == "string" then packages = {packages} end

    assert(type(packages) == "table", "depends.get_dependencies: Argument 'packages' is not a table or string.")
    assert(type(installed) == "table", "depends.get_dependencies: Argument 'installed' is not a table.")
    assert(type(manifest) == "table", "depends.get_dependencies: Argument 'manifest' is not a table.")

    local tmp_installed = utils.deepcopy(installed)

    -- add provided packages to installed ones
    for _, installed_pkg in pairs(tmp_installed) do
        for _, pkg in pairs(get_provides(installed_pkg)) do
            table.insert(tmp_installed, pkg)
        end
    end

    local to_install = {}

    -- get packages needed to to satisfy dependencies
    for _, pkg in pairs(packages) do

        local needed_to_install, err = get_packages_to_install(pkg, tmp_installed, manifest)

        if needed_to_install then
            for _, needed_pkg in pairs(needed_to_install) do
                table.insert(to_install, needed_pkg)
                table.insert(tmp_installed, needed_pkg)
                -- add provides of needed_pkg to installed ones
                for _, provided_pkg in pairs(get_provides(needed_pkg)) do
                    -- copy 'selected' property
                    provided_pkg.selected = needed_pkg.selected
                    table.insert(tmp_installed, provided_pkg)
                end
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

-- Return only packages that can be installed on the specified architecture and type
function filter_packages_by_arch_and_type(packages, req_arch, req_type)
    assert(type(packages) == "table", "depends.filter_packages_by_arch_and_type: Argument 'packages' is not a table.")
    assert(type(req_arch) == "string", "depends.filter_packages_by_arch_and_type: Argument 'req_arch' is not a string.")
    assert(type(req_type) == "string", "depends.filter_packages_by_arch_and_type: Argument 'pkg_type' is not a string.")

    return utils.filter_by(function (pkg)
                                return (pkg.arch == "Universal" or pkg.arch == req_arch) and
                                        (pkg.type == "all" or pkg.type == "source" or pkg.type == req_type)
                                end,
                            packages)
end

-- Return only packages that contain one of the specified strings in their 'name-version'.
-- If no strings were specified, return all the packages.
function filter_packages_by_strings(packages, strings)
    if type(strings) == "string" then strings = {strings} end
    assert(type(packages) == "table", "depends.filter_packages_by_strings: Argument 'packages' is not a table.")
    assert(type(strings) == "table", "depends.filter_packages_by_strings: Argument 'strings' is not a string or table.")

    if #strings ~= 0 then
        return utils.filter_by(function (pkg)
                                    for _,str in pairs(strings) do
                                        local name = pkg.name .. "-" .. pkg.version
                                        if name:find(str, 1 ,true) ~= nil then return true end
                                    end
                                end,
                                packages)
    else
        return packages
    end
end


-- Return full package name and version string (e.g. 'luajit-2.0'). When version
-- is nil or '' then return only name (e.g. 'luajit') and when name is nil or ''
-- then return '<unknown>'.
function pkg_full_name(name, version)
    name = name or ""
    version = version or ""

    if type(version) == "number" then version = tostring(version) end

    assert(type(name) == "string", "depends.pkg_full_name: Argument 'name' is not a string.")
    assert(type(version) == "string", "depends.pkg_full_name: Argument 'version' is not a string.")

    if name == "" then
        return "<unknown>"
    else
        return name .. ((version ~= "") and "-" .. version or "")
    end
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
