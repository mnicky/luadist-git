-- main API of LuaDist

module ("dist", package.seeall)

local cfg = require "dist.config"
local dep = require "dist.depends"
local git = require "dist.git"
local sys = require "dist.sys"
local mf = require "dist.manifest"

-- Return packages deployed in 'deploy_dir' also with their provides
function get_deployed(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.get_deployed: Argument 'deploy_dir' is not a string.")

    local deployed = depends.get_installed(deploy_dir)
    local provided = {}

    for _, pkg in pairs(deployed) do
        for _, provided_pkg in pairs(depends.get_provides(pkg)) do
            table.insert(provided, provided_pkg)
        end
    end

    for _, provided_pkg in pairs(provided) do
        table.insert(deployed, provided_pkg)
    end

    return deployed
end

-- Download new 'manifest_file' from repository and returns it.
-- Return nil and error message on error.
function update_manifest(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.update_manifest: Argument 'deploy_dir' is not a string.")

    -- make backup and delete the old manifest file
    sys.copy(deploy_dir .. "/" .. cfg.manifest_file, deploy_dir .. "/" .. cfg.temp_dir)
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

    -- resolve dependencies
    local dependencies, err = dep.get_depends(package_names, deploy_dir)
    if err then return nil, err end

    -- fetch the packages from repository
    local dirs_or_err = {}
    local ok, dirs_or_err = fetch_pkgs(dependencies, deploy_dir .. "/" .. cfg.temp_dir)
    if not ok then return nil, dirs_or_err end

    -- install fetched packages
    for _, dir in pairs(dirs_or_err) do
        ok, err = install_pkg(dir, deploy_dir)
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
        local ok, err = remove_pkg(pkg_distinfo_dir, deploy_dir)
        if not ok then return nil, err end
    end

    return true
end

-- Remove package from 'pkg_dir' of 'deploy_dir'.
function remove_pkg(pkg_dir, deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir

    assert(type(pkg_dir) == "string", "dist.remove_pkg: Argument 'pkg_dir' is not a string.")
    assert(type(deploy_dir) == "string", "dist.remove_pkg: Argument 'deploy_dir' is not a string.")

    -- check for dist.info
    local info, err = mf.load_distinfo(deploy_dir .. "/" .. pkg_dir .. "/dist.info")
    if not info then return nil, "Error removing package from '" .. pkg_dir .. "' - it doesn't contain valid 'dist.info' file." end
    if not info.files then return nil, "File '" .. pkg_dir .. "/dist.info" .."' doesn't contain list of installed files." end

    -- remove installed files
    for i = #info.files, 1, -1 do
        local f = deploy_dir .. "/" .. info.files[i]
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
    local ok = sys.delete(deploy_dir .. "/" .. pkg_dir)
    if not ok then return nil, "Error removing package in '" .. deploy_dir .. "/" .. pkg_dir .. "'." end

    return ok
end

-- Install package from 'pkg_dir' to 'deploy_dir', using optional CMake 'variables'.
function install_pkg(pkg_dir, deploy_dir, variables)

    deploy_dir = deploy_dir or cfg.root_dir
    variables = variables or {}

    assert(type(pkg_dir) == "string", "dist.make_pkg: Argument 'pkg_dir' is not a string.")
    assert(type(deploy_dir) == "string", "dist.make_pkg: Argument 'deploy_dir' is not a string.")
    assert(type(variables) == "table", "dist.make_pkg: Argument 'variables' is not a table.")

    -- check for dist.info
    local info, err = mf.load_distinfo(pkg_dir .. "/dist.info")
    if not info then return nil, "Error installing '" .. info.name .. "-" .. info.version .. "': package in '" .. pkg_dir .. "' doesn't contain valid 'dist.info' file." end

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

        -- TODO wouldn't it be better to move this into config.lua ?
        cmake_variables.CMAKE_INCLUDE_PATH = table.concat({cmake_variables.CMAKE_INCLUDE_PATH or "", deploy_dir .. "/include"}, ";")
        cmake_variables.CMAKE_LIBRARY_PATH = table.concat({cmake_variables.CMAKE_LIBRARY_PATH or "", deploy_dir .. "/lib", deploy_dir .. "/bin"}, ";")
        cmake_variables.CMAKE_PROGRAM_PATH = table.concat({cmake_variables.CMAKE_PROGRAM_PATH or "", deploy_dir .. "/bin"}, ";")

        -- build the package
        local build_dir, err = build_pkg(pkg_dir, deploy_dir .. "/" .. cfg.temp_dir, cmake_variables)
        if not build_dir then return nil, err end

        -- and deploy it
        ok, err = deploy_pkg(build_dir, deploy_dir)
        if not cfg.debug then sys.delete(build_dir) end
    end

    -- delete directory of fetched package
    if not cfg.debug then sys.delete(pkg_dir) end

    return ok, err
end

-- Build package from 'src_dir' to 'build_dir' using 'variables'.
-- Return directory to which the package was built or nil on error.
-- 'variables' is table of optional CMake variables.
function build_pkg(src_dir, build_dir, variables)

    build_dir = build_dir or sys.current_dir()
    variables = variables or {}

    assert(type(src_dir) == "string", "dist.build_pkg: Argument 'src_dir' is not a string.")
    assert(type(build_dir) == "string", "dist.build_pkg: Argument 'build_dir' is not a string.")
    assert(type(variables) == "table", "dist.build_pkg: Argument 'variables' is not a table.")

    -- check for dist.info
    local info, err = mf.load_distinfo(src_dir .. "/dist.info")
    if not info then return nil, "Error building package from '" .. src_dir .. "': it doesn't contain valid 'dist.info' file." end

    -- set machine information
    info.arch = cfg.arch
	info.type = cfg.type

    -- create build dirs
    local pkg_build_dir = build_dir .. "/" .. info.name .. "-" .. info.version .. "-" .. cfg.arch .. "-" .. cfg.type
    local cmake_build_dir = build_dir .. "/" .. info.name .. "-" .. info.version .. "-CMake-build"
    sys.make_dir(pkg_build_dir)
    sys.make_dir(cmake_build_dir)

    -- create cmake cache
    variables["CMAKE_INSTALL_PREFIX"] = pkg_build_dir
    local cache_file = io.open(cmake_build_dir .. "/cache.cmake", "w")
    if not cache_file then return nil, "Error creating CMake cache file in '" .. cmake_build_dir .. "'" end
    for k,v in pairs(variables) do
        cache_file:write("SET(" .. k .. " \"" .. v .. "\"" .. " CACHE STRING \"\" FORCE)\n")
    end
    cache_file:close()

    -- change the directory
    --local prev_cur_dir = sys.current_dir()
    --sys.change_dir(cmake_build_dir)

    src_dir = sys.get_absolute_path(src_dir)

    -- set the cmake cache
    local ok = sys.exec("cd " .. sys.quote(cmake_build_dir) .. " && " .. cfg.cmake .. " -C cache.cmake " .. sys.quote(src_dir))
    if not ok then return nil, "Error preloading the CMake cache script '" .. cmake_build_dir .. "/cmake.cache" .. "'" end

    -- build with cmake
    ok = sys.exec("cd " .. sys.quote(cmake_build_dir) .. " && " .. cfg.build_command)
    if not ok then return nil, "Error building with CMake in directory '" .. cmake_build_dir .. "'" end

    -- add dist.info
    ok, err = mf.save_distinfo(info, pkg_build_dir .. "/dist.info")
    if not ok then return nil, err end

    -- clean up
    if not cfg.debug then
        sys.delete(cmake_build_dir)
    end

    return pkg_build_dir
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
