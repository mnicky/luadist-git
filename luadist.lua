#!/usr/bin/env lua

-- Command line interface to LuaDist-git.

local dist = require "dist"
local utils = require "dist.utils"
local depends = require "dist.depends"
local mf = require "dist.manifest"
local cfg = require "dist.config"
local sys = require "dist.sys"

local commands
commands = {

    -- Print help for this command line interface.
    ["help"] = {
        help = [[
LuaDist-git is Lua package manager for the LuaDist deployment system.
Released under the MIT License. See https://github.com/luadist/luadist-git

        Usage: luadist [DEPLOYMENT_DIRECTORY] <COMMAND> [OTHER...]

        Commands:

            help      - print this help
            install   - install modules
            remove    - remove modules
            refresh   - update information about modules in repositories
            list      - list installed modules
            info      - show information about modules
            search    - search repositories for modules
            make      - manually deploy modules from local paths
            fetch     - download modules
            selftest  - run the selftest of luadist

        To get help on specific command, run:
            luadist help <COMMAND>
        ]],
        run = function (deploy_dir, help_item)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            help_item = help_item or {}
            assert(type(deploy_dir) == "string", "luadist.help: Argument 'deploy_dir' is not a string.")
            assert(type(help_item) == "table", "luadist.help: Argument 'help_item' is not a table.")

            if not help_item or not commands[help_item[1]] then
                help_item = "help"
            else
                help_item = help_item[1]
            end

            print(commands[help_item].help)
            return 0
        end
    },

    -- Install modules.
    ["install"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] install MODULES...

The 'install' command will install specified modules to DEPLOYMENT_DIRECTORY.
LuaDist will also automatically resolve, download and install all dependencies.

If DEPLOYMENT_DIRECTORY is not specified, the deployment directory of LuaDist
is used.
        ]],

        run = function (deploy_dir, modules)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            if type(modules) == "string" then modules = {modules} end

            assert(type(deploy_dir) == "string", "luadist.install: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.install: Argument 'modules' is not a string or table.")

            if #modules == 0 then
                print("No modules to install specified.")
                return 0
            end

            local ok, err = dist.install(modules, deploy_dir)
            if not ok then
                print(err)
                return 1
            else
               print("Installation successful.")
               return 0
            end
        end
    },

    -- Remove modules.
    ["remove"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] remove MODULES...

The 'remove' command will remove specified modules from DEPLOYMENT_DIRECTORY.

If DEPLOYMENT_DIRECTORY is not specified, the deployment directory of LuaDist
is used.

WARNING: dependencies between modules are NOT taken into account!
        ]],

        run = function (deploy_dir, modules)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            if type(modules) == "string" then modules = {modules} end

            assert(type(deploy_dir) == "string", "luadist.remove: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.remove: Argument 'modules' is not a string or table.")

            if #modules == 0 then
                print("No modules to remove specified.")
                return 0
            end

            local ok, err = dist.remove(modules, deploy_dir)
            if not ok then
                print(err)
                return 1
            else
               print("Removal successful.")
               return 0
            end
        end
    },

    -- Update repositories.
    ["refresh"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] refresh

The 'refresh' command will update information about modules in all software
repositories of specified DEPLOYMENT_DIRECTORY.

If DEPLOYMENT_DIRECTORY is not specified, the deployment directory of LuaDist
is used.
        ]],

        run = function (deploy_dir)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            assert(type(deploy_dir) == "string", "luadist.refresh: Argument 'deploy_dir' is not a string.")

            local ok, err = dist.update_manifest(deploy_dir)
            if not ok then
                print(err)
                return 1
            else
               print("Repositories successfuly updated.")
               return 0
            end
        end
    },

    -- Manually deploy modules.
    ["make"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] make MODULE_PATHS...

The 'make' command will manually deploy modules from specified local
MODULE_PATHS into the DEPLOYMENT_DIRECTORY.

The MODULE_PATHS will be preserved. If DEPLOYMENT_DIRECTORY is not specified,
the deployment directory of LuaDist is used.

WARNING: this command does NOT check whether the dependencies of modules are
satisfied or not!
        ]],

        run = function (deploy_dir, module_paths)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            module_paths = module_paths or {}
            assert(type(deploy_dir) == "string", "luadist.make: Argument 'deploy_dir' is not a string.")
            assert(type(module_paths) == "table", "luadist.make: Argument 'module_paths' is not a table.")

            if #module_paths == 0 then
                print("No module paths to deploy specified.")
                return 0
            end

            local ok, err = dist.make(deploy_dir, module_paths)
            if not ok then
                print(err)
                return 1
            end
            print("Deployment sucessful.")
            return 0
        end
    },

    -- Download modules.
    ["fetch"] = {
        help = [[
Usage: luadist [FETCH_DIRECTORY] fetch MODULES...

The 'fetch' command will download specified MODULES to the FETCH_DIRECTORY.

If no FETCH_DIRECTORY is specified, the temporary directory of LuaDist
deployment directory (i.e. ']] .. cfg.temp_dir .. [[') is used.
If the version is not specified in module name, the most recent version
available will be downloaded.
        ]],

        run = function (fetch_dir, modules)
            fetch_dir = fetch_dir or dist.get_deploy_dir()modules = modules or {}
            assert(type(fetch_dir) == "string", "luadist.fetch: Argument 'fetch_dir' is not a string.")
            assert(type(modules) == "table", "luadist.fetch: Argument 'modules' is not a table.")

            if fetch_dir == dist.get_deploy_dir() then
                fetch_dir = fetch_dir .. "/" .. cfg.temp_dir
            end

            if #modules == 0 then
                print("No modules to download specified.")
                return 0
            end

            local ok, err = dist.fetch(modules, fetch_dir)
            if not ok then
                print(err)
                return 1
            else
                print("Modules successfuly downloaded to '" .. fetch_dir .. "'.")
                return 0
            end
        end
    },

    -- List installed modules.
    ["list"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] list [STRINGS...]

The 'list' command will list all modules installed in specified
DEPLOYMENT_DIRECTORY, which contain one or more optional STRINGS.

If DEPLOYMENT_DIRECTORY is not specified, the deployment directory of LuaDist
is used. If STRINGS are not specified, all installed modules are listed.
        ]],

        run = function (deploy_dir, strings)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            strings = strings or {}
            assert(type(deploy_dir) == "string", "luadist.list: Argument 'deploy_dir' is not a string.")
            assert(type(strings) == "table", "luadist.list: Argument 'strings' is not a table.")

            local deployed = dist.get_deployed(deploy_dir)
            deployed  = depends.filter_packages_by_strings(deployed, strings)

            print("\nInstalled modules:")
            print("==================\n")
            for _, pkg in pairs(deployed) do
                print("  " .. pkg.name .. "-" .. pkg.version .. "\t(" .. pkg.arch .. "-" .. pkg.type .. ")" .. (pkg.provided_by and "\t [provided by " .. pkg.provided_by .. "]" or ""))
            end
            print()
            return 0
        end
    },

    -- Search for modules in repositories.
    ["search"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] search [-d] [STRINGS...]

The 'search' command will list all modules from repositories, which contain
one or more STRINGS. This command also shows whether modules are installed
in DEPLOYMENT_DIRECTORY.

If no STRINGS are specified, all available modules are listed. If
DEPLOYMENT_DIRECTORY is not specified, the deployment directory of LuaDist is
used. Only modules suitable for the platform LuaDist is running on are showed.

The -d option makes luadist to search also in the description of modules.
        ]],

        run = function (deploy_dir, strings)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            strings = strings or {}
            assert(type(deploy_dir) == "string", "luadist.search: Argument 'deploy_dir' is not a string.")
            assert(type(strings) == "table", "luadist.search: Argument 'strings' is not a table.")

            local search_in_desc = false
            if strings[1] == "-d" then
                search_in_desc = true
                table.remove(strings, 1)
            end

            local available = mf.get_manifest()
            available = depends.filter_packages_by_strings(available, strings, search_in_desc)
            available = depends.filter_packages_by_arch_and_type(available, cfg.arch, cfg.type)
            available = depends.sort_by_names(available)
            local deployed = dist.get_deployed(deploy_dir)

            print("\nModules found:")
            print("==============\n")
            for _, pkg in pairs(available) do
                local installed = (depends.is_installed(pkg.name, deployed, pkg.version))
                print("  " .. (installed and "i " or "  ") .. pkg.name .. "-" .. pkg.version .. (pkg.desc and "\t\t" .. pkg.desc or ""))
            end
            print()
            return 0
        end
    },

    -- Show information about modules.
    ["info"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] info [MODULES...]

The 'info' command shows information about specified modules from repositories.
This command also shows whether modules are installed in DEPLOYMENT_DIRECTORY.

If no MODULES are specified, all available modules are showed.
If DEPLOYMENT_DIRECTORY is not specified, the deployment directory of LuaDist
is used.
        ]],

        run = function (deploy_dir, modules)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            modules = modules or {}
            assert(type(deploy_dir) == "string", "luadist.info: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.info: Argument 'modules' is not a table.")

            local manifest = mf.get_manifest()

            if #modules == 0 then
                modules = manifest
            else
                modules = depends.find_packages(modules, manifest)
            end

            modules = depends.sort_by_names(modules)
            local deployed = dist.get_deployed(deploy_dir)

            print("")
            for _, pkg in pairs(modules) do
                print("  " .. pkg.name .. "-" .. pkg.version .. "  (" .. pkg.arch .. "-" .. pkg.type ..")")
                print("  Description: " .. (pkg.desc or "N/A"))
                print("  Author: " .. (pkg.author or "N/A"))
                print("  Maintainer: " .. (pkg.maintainer or "N/A"))
                print("  Homepage: " .. (pkg.url or "N/A"))
                print("  License: " .. (pkg.license or "N/A"))
                print("  Repository url: " .. (pkg.path or "N/A"))
                if pkg.provides then print("  Provides: " .. utils.table_tostring(pkg.provides)) end
                if pkg.depends then print("  Depends: " .. utils.table_tostring(pkg.depends)) end
                if pkg.conflicts then print("  Conflicts: " .. utils.table_tostring(pkg.conflicts)) end
                print("  State: " .. (depends.is_installed(pkg.name, deployed, pkg.version) and "installed" or "not installed"))
                print()
            end
            return 0
        end
    },

    -- Selftest of luadist.
    ["selftest"] = {
        help = [[
Usage: luadist selftest

The 'selftest' command tests the luadist itself and displays the results.
        ]],

        run = function (deploy_dir)
            deploy_dir = deploy_dir or dist.get_deploy_dir()
            assert(type(deploy_dir) == "string", "luadist.selftest: Argument 'deploy_dir' is not a string.")
            local test_dir = deploy_dir .. "/" .. cfg.test_dir
            print("\nRunning tests:")
            print("==============")
            for item in sys.get_directory(test_dir) do
                item = test_dir .. "/" .. item
                if sys.is_file(item) then
                    print()
                    print(sys.extract_name(item) .. ":")
                    dofile(item)
                end
            end
            print()
            return 0
        end
    },
}

-- Run the 'command' in the 'deploy_dir' with other items starting
-- at 'other_idx' index of special variable 'arg.
local function run_command(deploy_dir, command, other_idx)
    local items = {}
    if other_idx then
        for i = other_idx, #arg do
            table.insert(items, arg[i])
        end
    end
    return commands[command].run(deploy_dir, items)
end


-- Parse command line input and run the required command.
if not commands[arg[1]] and commands[arg[2]] then
    -- deploy_dir specified
    return run_command(arg[1], arg[2], 3)
elseif commands[arg[1]] then
    -- deploy_dir not specified
    return run_command(dist.get_deploy_dir(), arg[1], 2)
else
    -- unknown command
    return run_command(dist.get_deploy_dir(), "help", 2)
end
