-- Working with manifest

module ("dist.manifest", package.seeall)

local cfg = require "dist.config"
local git = require "dist.git"
local sys = require "dist.sys"

-- Return manifest table
-- TODO: add deploy_dir argument ?
function get_manifest()

    -- get manifest from cache
    local manifest = load_manifest()

    --if manifest not in cache, download it
    if not manifest then
        download_manifest()
        manifest = load_manifest()
    end

    return manifest
end


-- Download manifest from git repository_url to dest_dir
function download_manifest(repository_url, dest_dir)

    -- if repository_url or dest_dir not specified, get it from config file
    repository_url = repository_url or cfg.repository_url
    dest_dir = dest_dir or cfg.cache_dir

    assert(type(repository_url) == "string", "manifest.download_manifest: Argument 'repository_url' is not a string.")
    assert(type(dest_dir) == "string", "manifest.download_manifest: Argument 'dest_dir' is not a string.")

    local clone_dir = cfg.temp_dir .. "/repository"

    -- clone the manifest repository and move the manifest to the cache
    if git.clone(repository_url, clone_dir, 1) then
        sys.move(clone_dir .. "/dist.manifest", dest_dir)
        sys.delete(clone_dir)
        return true
    else
        return nil, "Error when downloading the manifest from: " .. repository_url
    end
end

-- Load and return manifest table from the manifest file.
-- If manifest file not present, return nil.
function load_manifest(manifest_file)
    manifest_file = manifest_file or cfg.manifest_file

    assert(type(manifest_file) == "string", "manifest.load_manifest: Argument 'manifest_file' is not a string.")

    if (sys.exists(manifest_file)) then
        -- load the manifest file
        local manifest = loadfile(manifest_file)

        -- set clear environment for the manifest file execution
        local manifest_env = {}
        setfenv(manifest, manifest_env)

        return manifest()
    else
        return nil, "Error when loading the manifest from file: " .. manifest_file
    end
end

-- Load and return package info table from the distinfo_file file.
-- If file not present, return nil.
function load_distinfo(distinfo_file)

    assert(type(distinfo_file) == "string", "manifest.load_distinfo: Argument 'distinfo_file' is not a string.")


    if (sys.exists(distinfo_file)) then

        -- load the distinfo file
        local distinfo = loadfile(distinfo_file)

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

    -- TODO add error message
    return true
end


