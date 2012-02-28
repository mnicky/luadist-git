-- Working with manifest and dist.info files

module ("dist.manifest", package.seeall)

local cfg = require "dist.config"
local git = require "dist.git"
local sys = require "dist.sys"
local utils = require "dist.utils"

-- Return the manifest table from 'manifest_file'. If the manifest is in cache,
-- then the cached version is used. You can set the cache timeout value in
-- 'config.cache_timeout' variable.
-- If optional 'force_no_cache' parameter is true, then the cache is not used.
function get_manifest(manifest_file, force_no_cache)
    manifest_file = manifest_file or sys.make_path(cfg.root_dir, cfg.manifest_file)
    force_no_cache = force_no_cache or false

    assert(type(manifest_file) == "string", "manifest.get_manifest: Argument 'manifest_file' is not a string.")
    assert(type(force_no_cache) == "boolean", "manifest.get_manifest: Argument 'force_no_cache' is not a boolean.")
    manifest_file = sys.abs_path(manifest_file)

    -- download new manifest to the cache if not present or cache not used or cache expired
    if not sys.exists(manifest_file) or force_no_cache or not cfg.cache or utils.cache_timeout_expired(cfg.cache_timeout, manifest_file) then
        local manifest_dest = sys.parent_dir(manifest_file) or sys.current_dir()
        local ok, err = download_manifest(manifest_dest, cfg.repositories)
        if not ok then return nil, err end
    end

    -- load manifest from cache
    local manifest, err = load_manifest(manifest_file)
    if not manifest then return nil, err end

    return manifest
end

-- Download manifest from the table of git 'repository_urls' to 'dest_dir' and return true on success
-- and nil and error message on error.
function download_manifest(dest_dir, repository_urls)
    dest_dir = dest_dir or sys.make_path(cfg.root_dir, cfg.cache_dir)
    repository_urls = repository_urls or cfg.repositories
    if type(repository_urls) == "string" then repository_urls = {repository_urls} end

    assert(type(dest_dir) == "string", "manifest.download_manifest: Argument 'dest_dir' is not a string.")
    assert(type(repository_urls) == "table", "manifest.download_manifest: Argument 'repository_urls' is not a table or string.")
    dest_dir = sys.abs_path(dest_dir)

    local manifest = {}
    print("Downloading repository information...")

    for _, repo in pairs(repository_urls) do
        local clone_dir = sys.make_path(cfg.root_dir, cfg.temp_dir, "repository")

        -- clone the repo and add its 'dist.manifest' to manifest
        if git.clone(repo, clone_dir, 1) then
            for _, pkg in pairs(load_manifest(sys.make_path(clone_dir, "dist.manifest"))) do
                table.insert(manifest, pkg)
            end
            sys.delete(clone_dir)
        else
            sys.delete(clone_dir)
            return nil, "Error when downloading the manifest from: '" .. repo .. "'."
        end
    end

    -- save the manifest
    sys.make_dir(dest_dir)
    local ok, err = save_manifest(manifest, sys.make_path(dest_dir, "dist.manifest"))
    if not ok then return nil, err end

    return true
end

-- Load and return manifest table from the manifest file.
-- If manifest file not present, return nil.
function load_manifest(manifest_file)
    manifest_file = manifest_file or sys.make_path(cfg.root_dir, cfg.manifest_file)
    assert(type(manifest_file) == "string", "manifest.load_manifest: Argument 'manifest_file' is not a string.")
    manifest_file = sys.abs_path(manifest_file)

    if sys.exists(manifest_file) then
        -- load the manifest file
        local manifest, err = loadfile(manifest_file)
        if not manifest then return nil, err end

        -- set clear environment for the manifest file execution
        local manifest_env = {}
        setfenv(manifest, manifest_env)

        return manifest()
    else
        return nil, "Error when loading the manifest from file: " .. manifest_file
    end
end

-- Save manifest table to the 'file'
function save_manifest(manifest_table, file)
    assert(type(manifest_table) == "table", "manifest.save_distinfo: Argument 'manifest_table' is not a table.")
    assert(type(file) == "string", "manifest.save_distinfo: Argument 'file' is not a string.")
    file = sys.abs_path(file)

    -- Print table 'tbl' to io stream 'file'.
    local function print_table(file, tbl, in_nested_table)
        for k, v in pairs(tbl) do
            -- print key
            if in_nested_table then file:write("\t\t") end
            if type(k) ~= "number" then
                file:write("['" .. k .. "']" .. " = ")
            end
            -- print value
            if type(v) == "table" then
                file:write("{\n")
                print_table(file, v, true)
                if in_nested_table then file:write("\t") end
                file:write("\t}")
            else
                if in_nested_table then file:write("\t") end
                if type(v) == "string" then
                    file:write('[[' .. v .. ']]')
                else
                    file:write(v)
                end
            end
            file:write(",\n")
        end
    end

    local manifest_file = io.open(file, "w")
    if not manifest_file then return false, "Error saving table: cannot open the file '" .. file .. "'." end

    manifest_file:write('return {\n')
    print_table(manifest_file, manifest_table)
    manifest_file:write('},\ntrue')
    manifest_file:close()

    return true
end

-- Load and return package info table from the distinfo_file file.
-- If file not present, return nil.
function load_distinfo(distinfo_file)
    assert(type(distinfo_file) == "string", "manifest.load_distinfo: Argument 'distinfo_file' is not a string.")
    distinfo_file = sys.abs_path(distinfo_file)

    if sys.exists(distinfo_file) then

        -- load the distinfo file
        local distinfo, err = loadfile(distinfo_file)
        if not distinfo then return nil, err end

        -- set clear environment for the distinfo file execution and collect values into it
        local distinfo_env = {}
        setfenv(distinfo, distinfo_env)
        distinfo()

        return distinfo_env
    else
        return nil, "Error when loading the package info from file: " .. distinfo_file
    end
end

-- Save distinfo table to the 'file'
function save_distinfo(distinfo_table, file)
    assert(type(distinfo_table) == "table", "manifest.save_distinfo: Argument 'distinfo_table' is not a table.")
    assert(type(file) == "string", "manifest.save_distinfo: Argument 'file' is not a string.")
    file = sys.abs_path(file)

    -- Print table 'tbl' to io stream 'file'.
    local function print_table(file, tbl, in_nested_table)
        for k, v in pairs(tbl) do
            -- print key
            if type(k) ~= "number" then
                file:write(k .. " = ")
            end
            -- print value
            if type(v) == "table" then
                file:write("{\n")
                print_table(file, v, true)
                file:write("}\n")
            elseif type(v) == "string" then
                if in_nested_table then
                    file:write('[[' .. v .. ']]')
                else
                    file:write('"' .. v .. '"')
                end
            else
                file:write(v)
            end
            if in_nested_table then
                file:write(",")
            end
            file:write("\n")
        end
    end

    local distinfo_file = io.open(file, "w")
    if not distinfo_file then return false, "Error saving table: cannot open the file '" .. file .. "'." end

    print_table(distinfo_file, distinfo_table)
    distinfo_file:close()

    return true
end
