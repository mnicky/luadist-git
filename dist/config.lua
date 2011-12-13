-- Luadist configuration

module ("dist.config", package.seeall)

-- TODO: get rid of lfs dependency in this module (replace with dist.sys)
local lfs = require "lfs"

-- System information
version = "1.2"     -- Current LuaDist version
arch	= "Linux"   -- Host architecture
type	= "i686"	-- Host type


-- Paths
root_dir      = lfs.currentdir()
temp_dir      = root_dir .. "/tmp"
cache_dir     = temp_dir .. "/cache"
distinfos_dir = "share/luadist/dists"

-- Files
manifest_file = cache_dir .. "/dist.manifest"

-- URLs
repository_url = "https://github.com/LuaDist/Repository.git"

-- Settings
debug = false

-- CMake variables
variables	= {

    --- Install defaults
    INSTALL_BIN                       = "bin",
    INSTALL_LIB                       = "lib",
    INSTALL_INC                       = "include",
    INSTALL_ETC                       = "etc",
    INSTALL_LMOD                      = "lib/lua",
    INSTALL_CMOD                      = "lib/lua",

	--- LuaDist specific variables
	DIST_VERSION                       = version,
	DIST_ARCH                          = arch,
	DIST_TYPE                          = type,

	-- CMake specific setup
	CMAKE_GENERATOR                    = "Unix Makefiles",
	CMAKE_BUILD_TYPE                   = "MinSizeRel",

    -- RPath functionality
    CMAKE_SKIP_BUILD_RPATH             = "FALSE",
    CMAKE_BUILD_WITH_INSTALL_RPATH     = "FALSE",
    CMAKE_INSTALL_RPATH                = "$ORIGIN/../lib",
    CMAKE_INSTALL_RPATH_USE_LINK_PATH  = "TRUE",
    CMAKE_INSTALL_NAME_DIR             = "@executable_path/../lib",

	-- OSX specific
	CMAKE_OSX_ARCHITECTURES            = "",
}

-- Building
cmake         = "cmake"
ctest         = "ctest"
build_command = cmake .. " --build . --target install --clean-first"

if debug then
    cmake = cmake .. " -DCMAKE_VERBOSE_MAKEFILE=true -DCMAKE_BUILD_TYPE=Debug"
end

-- Add -j option to make in case of unix makefiles to speed up builds
if (variables.CMAKE_GENERATOR == "Unix Makefiles") then
        build_command = build_command .. " -- -j6"
end
