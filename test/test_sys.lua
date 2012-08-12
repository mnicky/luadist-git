-- Tests of LuaDist's system functions

local dist = require "dist"
local cfg = require "dist.config"
local sys = require "dist.sys"

-- Return test fail message.
local function fail_msg(val, err)
    if not val then
        return "TEST FAILED!!! - Returned value was: 'nil' \n    Error was: \"" .. (err or "nil") .. "\""
    else
        return "TEST FAILED!!! - Returned value was: '" .. val .. "' \n    Error was: \"" .. (err or "nil") .. "\""
    end
end

-- Run all the 'tests' and display results.
local function run_tests(tests)
    local passed = 0
    local failed = 0

    for name, test in pairs(tests) do
        local ok, err = pcall(test)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("In '" .. name .. "()': " .. err)
        end
    end
    if failed > 0 then print("----------------------------------") end
    print("Passed " .. passed .. "/" .. passed + failed .. " tests (" .. failed .. " failed).")
end


-- Test suite.
local tests = {}

-- remember the original system architecture (DO NOT REMOVE!)
local original_arch = cfg.arch

--- ========== SYSTEM FUNCTIONALITY TESTS ==========


--- path separator

tests.path_separator_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.path_separator()
    assert(val == "/", fail_msg(val, err))
end

tests.path_separator_win = function()
    cfg.arch = "Windows"
    local val, err = sys.path_separator()
    assert(val == "\\", fail_msg(val, err))
end

-- tests.template = function()
--     local val, err = sys.function()
--     assert(val == nil and err:find("error msg"), fail_msg(val, err))
-- end



run_tests(tests)

-- set the original system architecture back (DO NOT REMOVE!)
cfg.arch = original_arch
