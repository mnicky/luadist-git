-- Working with manifest

module ("dist.manifest", package.seeall)

local cfg = require "dist.config"
local git = require "dist.git"
local sys = require "dist.sys"

-- Return manifest table
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

    assert(type(repository_url) == "string", "dist.manifest: Argument 'repository_url' is not a string.")
    assert(type(dest_dir) == "string", "dist.manifest: Argument 'dest_dir' is not a string.")

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

    assert(type(manifest_file) == "string", "dist.manifest: Argument 'manifest_file' is not a string.")

    if (sys.exists(manifest_file)) then
        -- evaluate the manifest file
        return dofile(manifest_file)
    else
        return nil, "Error when loading the manifest from file: " .. manifest_file
    end
end
