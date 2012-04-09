LuaDist-GIT
===========

[![Build Status](https://secure.travis-ci.org/LuaDist/luadist-git.png?branch=master)](http://travis-ci.org/LuaDist/luadist-git)

LuaDist-GIT is Lua module deployment utility for the LuaDist project [1]. In fact it's another version of luadist utility [2], rewritten from scratch.


Main Goals
----------

 * access git repositories directly and get rid of unnecessary
   dependencies (i.e. luasocket, luasec, md5, openssl, unzip)

 * use .gitmodules as a repository manifest file instead of dist.manifest,
   thus removing the need to update the manifest after every change in modules

 * add functionality for uploading binary versions of modules to repositories

 * once libgit2 [3] matures we will replace the CLI git commands

____________________________________________
[1] https://github.com/LuaDist
[2] https://github.com/LuaDist/luadist
[3] https://github.com/libgit2/libgit2
