-- Luadist configuration

module ("dist.config", package.seeall)

local lfs = require "lfs"


-- System information
arch = "unix"
type = "x86"

-- Paths
root_dir = lfs.currentdir()
temp_dir = root_dir .. "/tmp"
cache_dir = temp_dir .. "/cache"

-- Files
manifest_file = cache_dir .. "/dist.manifest"

-- URLs
repository_url = "https://github.com/LuaDist/Repository.git"
