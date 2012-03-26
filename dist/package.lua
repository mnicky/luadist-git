-- Package functions

module ("dist.package", package.seeall)

local cfg = require "dist.config"
local git = require "dist.git"
local sys = require "dist.sys"
local mf = require "dist.manifest"
local utils = require "dist.utils"
local depends = require "dist.depends"

-- Remove package from 'pkg_dir' of 'deploy_dir'.
function remove_pkg(pkg_distinfo_dir, deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(pkg_distinfo_dir) == "string", "package.remove_pkg: Argument 'pkg_distinfo_dir' is not a string.")
    assert(type(deploy_dir) == "string", "package.remove_pkg: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    local abs_pkg_distinfo_dir = sys.make_path(deploy_dir, pkg_distinfo_dir)

    -- check for dist.info
    local info, err = mf.load_distinfo(sys.make_path(abs_pkg_distinfo_dir, "dist.info"))
    if not info then return nil, "Error removing package from '" .. pkg_distinfo_dir .. "' - it doesn't contain valid 'dist.info' file." end
    if not info.files then return nil, "File '" .. sys.make_path(pkg_distinfo_dir, "dist.info") .."' doesn't contain list of installed files." end

    -- remove installed files
    for i = #info.files, 1, -1 do
        local f = sys.make_path(deploy_dir, info.files[i])
        if sys.is_file(f) then
            sys.delete(f)
        elseif sys.is_dir(f) then
            local dir_files = sys.get_file_list(f)

            if #dir_files == 0 then
                sys.delete(f)
            end
        end
    end

    -- delete package info from deploy_dir
    local ok = sys.delete(abs_pkg_distinfo_dir)
    if not ok then return nil, "Error removing package in '" .. abs_pkg_distinfo_dir .. "'." end

    return ok
end

-- Install package from 'pkg_dir' to 'deploy_dir', using optional CMake 'variables'.
-- Optional 'preserve_pkg_dir' argument specified whether to preserve the 'pkg_dir'.
-- If optional 'simulate' argument is true, the installation of package will
-- be only simulated.
function install_pkg(pkg_dir, deploy_dir, variables, preserve_pkg_dir, simulate)
    deploy_dir = deploy_dir or cfg.root_dir
    variables = variables or {}
    preserve_pkg_dir = preserve_pkg_dir or false
    simulate = simulate or false

    assert(type(pkg_dir) == "string", "package.install_pkg: Argument 'pkg_dir' is not a string.")
    assert(type(deploy_dir) == "string", "package.install_pkg: Argument 'deploy_dir' is not a string.")
    assert(type(variables) == "table", "package.install_pkg: Argument 'variables' is not a table.")
    assert(type(preserve_pkg_dir) == "boolean", "package.install_pkg: Argument 'preserve_pkg_dir' is not a boolean.")
    assert(type(simulate) == "boolean", "package.install_pkg: Argument 'simulate' is not a boolean.")

    pkg_dir = sys.abs_path(pkg_dir)
    deploy_dir = sys.abs_path(deploy_dir)

    -- check for dist.info
    local info, err = mf.load_distinfo(sys.make_path(pkg_dir, "dist.info"))
    if not info then return nil, "Error installing: the directory '" .. pkg_dir .. "' doesn't exist or doesn't contain valid 'dist.info' file." end

    -- check if the package is source
    if sys.exists(sys.make_path(pkg_dir, "CMakeLists.txt")) then
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
        ok, err = deploy_pkg(pkg_dir, deploy_dir, simulate)

    -- else build and then deploy
    else
        -- set cmake variables
        local cmake_variables = {}

        -- set variables from config file
        for k, v in pairs(cfg.variables) do
            cmake_variables[k] = v
        end

        -- set variables specified as argument
        for k, v in pairs(variables) do
            cmake_variables[k] = v
        end

        cmake_variables.CMAKE_INCLUDE_PATH = table.concat({cmake_variables.CMAKE_INCLUDE_PATH or "", sys.make_path(deploy_dir, "include")}, ";")
        cmake_variables.CMAKE_LIBRARY_PATH = table.concat({cmake_variables.CMAKE_LIBRARY_PATH or "", sys.make_path(deploy_dir, "lib"), sys.make_path(deploy_dir, "bin")}, ";")
        cmake_variables.CMAKE_PROGRAM_PATH = table.concat({cmake_variables.CMAKE_PROGRAM_PATH or "", sys.make_path(deploy_dir, "bin")}, ";")

        -- build the package
        local build_dir, temp_dir = nil, sys.make_path(deploy_dir, cfg.temp_dir)
        build_dir, err = build_pkg(pkg_dir, temp_dir, cmake_variables)
        if not build_dir then return nil, err end

        -- and deploy it
        ok, err = deploy_pkg(build_dir, deploy_dir, simulate)
        if not cfg.debug then sys.delete(build_dir) end

    end

    -- delete directory of fetched package
    if not (cfg.debug or preserve_pkg_dir) then sys.delete(pkg_dir) end

    return ok, err
end

-- Build package from 'src_dir' to 'build_dir' using 'variables'.
-- Return directory to which the package was built or nil on error.
-- 'variables' is table of optional CMake variables.
function build_pkg(src_dir, build_dir, variables)
    build_dir = build_dir or sys.current_dir()
    variables = variables or {}

    assert(type(src_dir) == "string", "package.build_pkg: Argument 'src_dir' is not a string.")
    assert(type(build_dir) == "string", "package.build_pkg: Argument 'build_dir' is not a string.")
    assert(type(variables) == "table", "package.build_pkg: Argument 'variables' is not a table.")

    src_dir = sys.abs_path(src_dir)
    build_dir = sys.abs_path(build_dir)

    -- check for dist.info
    local info, err = mf.load_distinfo(sys.make_path(src_dir, "dist.info"))
    if not info then return nil, "Error building package from '" .. src_dir .. "': it doesn't contain valid 'dist.info' file." end

    -- set machine information
    info.arch = cfg.arch
	info.type = cfg.type

    -- create build dirs
    local pkg_build_dir = sys.abs_path(sys.make_path(build_dir, info.name .. "-" .. info.version .. "-" .. cfg.arch .. "-" .. cfg.type))
    local cmake_build_dir = sys.abs_path(sys.make_path(build_dir, info.name .. "-" .. info.version .. "-CMake-build"))
    sys.make_dir(pkg_build_dir)
    sys.make_dir(cmake_build_dir)

    -- create cmake cache
    variables["CMAKE_INSTALL_PREFIX"] = pkg_build_dir
    local cache_file = io.open(sys.make_path(cmake_build_dir, "cache.cmake"), "w")
    if not cache_file then return nil, "Error creating CMake cache file in '" .. cmake_build_dir .. "'" end
    for k,v in pairs(variables) do
        cache_file:write("SET(" .. k .. " \"" .. v .. "\"" .. " CACHE STRING \"\" FORCE)\n")
    end
    cache_file:close()

    src_dir = sys.abs_path(src_dir)
    print("Building " .. sys.extract_name(src_dir) .. "...")

    -- set the cmake cache
    local ok = sys.exec("cd " .. sys.quote(cmake_build_dir) .. " && " .. cfg.cmake .. " -C cache.cmake " .. sys.quote(src_dir))
    if not ok then return nil, "Error preloading the CMake cache script '" .. sys.make_path(cmake_build_dir, "cmake.cache") .. "'" end

    -- build with cmake
    ok = sys.exec("cd " .. sys.quote(cmake_build_dir) .. " && " .. cfg.build_command)
    if not ok then return nil, "Error building with CMake in directory '" .. cmake_build_dir .. "'" end

    -- add dist.info
    ok, err = mf.save_distinfo(info, sys.make_path(pkg_build_dir, "dist.info"))
    if not ok then return nil, err end

    -- clean up
    if not cfg.debug then
        sys.delete(cmake_build_dir)
    end

    return pkg_build_dir
end

-- Deploy package from 'pkg_dir' to 'deploy_dir' by copying.
-- If optional 'simulate' argument is true, the deployment of package will
-- be only simulated.
function deploy_pkg(pkg_dir, deploy_dir, simulate)
    deploy_dir = deploy_dir or cfg.root_dir
    simulate = simulate or false

    assert(type(pkg_dir) == "string", "package.deploy_pkg: Argument 'pkg_dir' is not a string.")
    assert(type(deploy_dir) == "string", "package.deploy_pkg: Argument 'deploy_dir' is not a string.")
    assert(type(simulate) == "boolean", "package.deploy_pkg: Argument 'simulate' is not a boolean.")

    pkg_dir = sys.abs_path(pkg_dir)
    deploy_dir = sys.abs_path(deploy_dir)

    -- check for dist.info
    local info, err = mf.load_distinfo(sys.make_path(pkg_dir, "dist.info"))
    local pkg_name = info.name .. "-" .. info.version
    if not info then return nil, "Error deploying package from '" .. pkg_dir .. "': it doesn't contain valid 'dist.info' file." end

    -- delete the 'dist.info' file
    sys.delete(sys.make_path(pkg_dir, "dist.info"))

    -- if this is only simulation, exit sucessfully, skipping the next actions
    if simulate then
        return true, "Simulated deployment of package '" .. pkg_name .. "' sucessfull."
    end

    -- copy all files to the deploy_dir
    local ok, err = sys.copy(sys.make_path(pkg_dir, "."), deploy_dir)
    if not ok then return nil, "Error deploying package '" .. pkg_name .. "': " .. err end

    -- save modified 'dist.info' file
    info.files = sys.get_file_list(pkg_dir)
    local pkg_distinfo_dir = sys.make_path(deploy_dir, cfg.distinfos_dir, pkg_name)
    sys.make_dir(pkg_distinfo_dir)

    ok, err = mf.save_distinfo(info, sys.make_path(pkg_distinfo_dir, "dist.info"))
    if not ok then return nil, err end

    return true, "Package '" .. pkg_name .. "' successfully deployed to '" .. deploy_dir .. "'."
end

-- Fetch package (table 'pkg') to download_dir. Return path to the directory of
-- downloaded package on success or an error message on error.
function fetch_pkg(pkg, download_dir)
    download_dir = download_dir or sys.current_dir()
    assert(type(pkg) == "table", "package.fetch_pkg: Argument 'pkg' is not a table.")
    assert(type(download_dir) == "string", "package.fetch_pkg: Argument 'download_dir' is not a string.")
    assert(type(pkg.name) == "string", "package.fetch_pkg: Argument 'pkg.name' is not a string.")
    assert(type(pkg.version) == "string", "package.fetch_pkg: Argument 'pkg.version' is not a string.")
    assert(type(pkg.path) == "string", "package.fetch_pkg: Argument 'pkg.path' is not a string.")
    download_dir = sys.abs_path(download_dir)

    local pkg_full_name = pkg.name .. "-" .. pkg.version
    local repo_url = git.get_repo_url(pkg.path)
    local clone_dir = sys.abs_path(sys.make_path(download_dir, pkg_full_name))

    -- check if download_dir already exists, assuming the package was already downloaded
    -- XXX: use caching with timeout
    if sys.exists(sys.make_path(clone_dir, "dist.info")) then return clone_dir end

    -- clone pkg's repository
    print("Getting " .. pkg_full_name .. "...")
    local ok, err = git.clone(repo_url, clone_dir, 1)

    -- checkout git tag according to the version of pkg
    if ok and pkg.version ~= "scm" then
        ok, err = git.checkout_tag(pkg.version, clone_dir)
    end

    if not ok then
        -- clean up
        sys.delete(clone_dir)
        return nil, "Error fetching package '" .. pkg_full_name .. "' from '" .. pkg.path .. "' to '" .. download_dir .. "': " .. err
    end

    -- delete '.git' directory
    if not cfg.debug then sys.delete(sys.make_path(clone_dir, ".git")) end

    return clone_dir
end

-- Fetch packages (table 'packages') to 'download_dir'. Return table of paths
-- to the directories on success or an error message on error.
function fetch_pkgs(packages, download_dir)
    download_dir = download_dir or sys.current_dir()
    assert(type(packages) == "table", "package.fetch_pkgs: Argument 'packages' is not a table.")
    assert(type(download_dir) == "string", "package.fetch_pkgs: Argument 'download_dir' is not a string.")
    download_dir = sys.abs_path(download_dir)

    local fetched_dirs = {}
    local dir, err

    for _, pkg in pairs(packages) do
        dir, err = fetch_pkg(pkg, download_dir)
        if not dir then
            return nil, err
        else
            table.insert(fetched_dirs, dir)
        end
    end

    return fetched_dirs
end

-- Return table with information about available versions of 'package'.
function retrieve_versions(package, manifest)
    assert(type(package) == "string", "package.retrieve_versions: Argument 'string' is not a string.")
    assert(type(manifest) == "table", "package.retrieve_versions: Argument 'manifest' is not a table.")

    -- get package table
    local pkg_name = depends.split_name_constraint(package)
    local tmp_packages = depends.find_packages(pkg_name, manifest)

    if #tmp_packages == 0 then
        return nil, "No suitable candidate for package '" .. package .. "' found."
    else
        package = tmp_packages[1]
    end

    print("Finding out available versions of " .. package.name .. "...")

    -- get available versions
    local tags, err = git.get_remote_tags(package.path)
    if not tags then return nil, "Error when retrieving versions of package '" .. package.name .. "':" .. err end

    -- filter out tags of binary packages
    local versions = utils.filter(tags, function (tag) return tag:match("^[^%-]+%-?[^%-]*$") and true end)

    packages = {}

    -- create package information
    for _, version in pairs(versions) do
        pkg = {}
        pkg.name = package.name
        pkg.version = version
        pkg.path = package.path
        table.insert(packages, pkg)
    end

    return packages
end

-- Return table with information from package's dist.info
function retrieve_pkg_info(package)
    assert(type(package) == "table", "package.retrieve_pkg_info: Argument 'package' is not a table.")

    local tmp_dir = sys.abs_path(sys.make_path(cfg.root_dir, cfg.temp_dir))

    -- download the package
    local pkg_dir, err = fetch_pkg(package, tmp_dir)
    if not pkg_dir then return nil, "Error when retrieving the info about '" .. package.name .. "':" .. err end

    -- load information from 'dist.info'
    local info, err = mf.load_distinfo(sys.make_path(pkg_dir, "dist.info"))
    if not info then return nil, err end

    -- add 'path' attribute
    if package.path then info.path = package.path end

    -- set default arch/type if not explicitly stated and package is of source type
    if sys.exists(sys.make_path(pkg_dir, "CMakeLists.txt")) then
        info.arch = info.arch or "Universal"
        info.type = info.type or "source"
    elseif not (info.arch and info.type) then
        return nil, pkg_dir .. ": binary package missing arch or type in 'dist.info'."
    end

    return info
end
