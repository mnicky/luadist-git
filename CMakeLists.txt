# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš, Peter Kapec
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

project ( luadist-git NONE )
cmake_minimum_required ( VERSION 2.6 )
include ( dist.cmake )

## LuaDist settings
# Host specific setup
set ( DETECTED_TYPE ${CMAKE_SYSTEM_PROCESSOR} )
set ( DETECTED_ARCH ${CMAKE_SYSTEM_NAME} )

if ( CYGWIN )
	# Make sure Cygwin uses correct arch and type.
	set ( DETECTED_TYPE x86 )
	set ( DETECTED_ARCH Cygwin )
elseif ( MSVC )
	set ( DETECTED_TYPE MSVC32 )
endif ()

set ( DIST_VERSION 0.1 )
set ( DIST_TYPE ${DETECTED_TYPE} CACHE STRING "Host system type. PLEASE CHECK!" FORCE )
set ( DIST_ARCH ${DETECTED_ARCH} CACHE STRING "Host system architecture. PLEASE CHECK!" FORCE )

configure_file ( dist/config.lua.in ${CMAKE_CURRENT_BINARY_DIR}/dist/config.lua @ONLY )

# Install files
#install_lua_executable ( luadist luadist )
install_lua_module ( dist.config ${CMAKE_CURRENT_BINARY_DIR}/dist/config.lua )
install_lua_module ( dist.constraints dist/constraints.lua )
install_lua_module ( dist.depends dist/depends.lua )
install_lua_module ( dist.git dist/git.lua )
install_lua_module ( dist.init dist/init.lua )
install_lua_module ( dist.manifest dist/manifest.lua )
install_lua_module ( dist.sys dist/sys.lua )

install_data ( COPYRIGHT )
