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
        -- evaluate the manifest file
        return dofile(manifest_file)
    else
        return nil, "Error when loading the manifest from file: " .. manifest_file
    end
end

-- Load and return package info table from the distinfo_file file.
-- If file not present, return nil.
function load_distinfo(distinfo_file)

    assert(type(distinfo_file) == "string", "manifest.load_distinfo: Argument 'distinfo_file' is not a string.")

    distinfo = {}

    if (sys.exists(distinfo_file)) then

        -- TODO: run in local context somehow (to avoid assigning global variables)

        -- evaluate the distinfo file
        dofile(distinfo_file)

        -- collect values into distinfo table

        --if type then distinfo.type = type end
        if arch then distinfo.arch = arch end

        if name then distinfo.name = name end
        if version then distinfo.version = version end

        if desc then distinfo.desc = desc end
        if maintainer then distinfo.maintainer = maintainer end
        if author then distinfo.author = author end
        if license then distinfo.license = license end
        if url then distinfo.url = url end

        if files then distinfo.files = files end

        if depends then distinfo.depends = depends end
        if provides then distinfo.provides = provides end
        if conflicts then distinfo.conflicts = conflicts end
        if replaces then distinfo.replaces = replaces end

        return distinfo
    else
        return nil, "Error when loading the package info from file: " .. distinfo_file
    end
end




