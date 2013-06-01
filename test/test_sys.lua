-- Tests of LuaDist's system functions

local dist = require "dist"
local cfg = require "dist.config"
local sys = require "dist.sys"
local utils = require "dist.utils"
local lfs = require "lfs"

-- Return test fail message.
local function fail_msg(val, err)
    return "TEST FAILED!!! - Returned value was: '" .. (type(val) == "table" and utils.table_tostring(val) or tostring(val)) .. "' \n    Error was: \"" .. (tostring(err) or "nil") .. "\""
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
--- note: every test must start with the line: cfg.arch = intented_value


--- path_separator()

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

--- check_separators()

tests.check_separators_unix_1 = function()
    cfg.arch = "Linux"
    local val, err = sys.check_separators("/dir1/dir2/file")
    assert(val == "/dir1/dir2/file", fail_msg(val, err))
end

tests.check_separators_unix_2 = function()
    cfg.arch = "Linux"
    local val, err = sys.check_separators("\\very\\long\\filename")
    assert(val == "\\very\\long\\filename", fail_msg(val, err))
end

tests.check_separators_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.check_separators("C:/dir1/dir2/file.ext")
    assert(val == "C:\\dir1\\dir2\\file.ext", fail_msg(val, err))
end

tests.check_separators_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.check_separators("C:\\dir1\\dir2\\file.ext")
    assert(val == "C:\\dir1\\dir2\\file.ext", fail_msg(val, err))
end

--- remove_trailing()

tests.remove_trailing_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.remove_trailing("/dir1/dir2/dir3/")
    assert(val == "/dir1/dir2/dir3", fail_msg(val, err))
end

tests.remove_trailing_win = function()
    cfg.arch = "Windows"
    local val, err = sys.remove_trailing("C:\\dir1\\dir2\\dir3\\")
    assert(val == "C:\\dir1\\dir2\\dir3", fail_msg(val, err))
end
---
tests.remove_trailing_with_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.remove_trailing("/")
    assert(val == "/", fail_msg(val, err))
end

tests.remove_trailing_with_root_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.remove_trailing("C:\\")
    assert(val == "C:\\", fail_msg(val, err))
end

tests.remove_trailing_with_root_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.remove_trailing("\\")
    assert(val == "\\", fail_msg(val, err))
end
---
tests.remove_trailing_without_trailing_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.remove_trailing("/dir1/dir2/dir3")
    assert(val == "/dir1/dir2/dir3", fail_msg(val, err))
end

tests.remove_trailing_without_trailing_win = function()
    cfg.arch = "Windows"
    local val, err = sys.remove_trailing("C:\\dir1\\dir2\\dir3")
    assert(val == "C:\\dir1\\dir2\\dir3", fail_msg(val, err))
end

--- quote()

tests.quote_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.quote("/home/user")
    assert(val == "\"/home/user\"", fail_msg(val, err))
end

tests.quote_win = function()
    cfg.arch = "Windows"
    local val, err = sys.quote("C:\\WINDOWS\\system32/bad_slash_type")
    assert(val == "\"C:\\\\WINDOWS\\\\system32\\\\bad_slash_type\"", fail_msg(val, err))
end

--- exec()

tests.exec_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.exec("cd")
    assert(val == true and err:find("Sucessfully executed"), fail_msg(val, err))
end
---
tests.exec_nonexistent_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.exec("nonexistent")
    assert(val == nil and err:find("Error when running"), fail_msg(val, err))
end

--- is_root()

tests.is_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_root("/")
    assert(val == true, fail_msg(val, err))
end

tests.is_root_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_root("C:\\")
    assert(val == true, fail_msg(val, err))
end

tests.is_root_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_root("\\")
    assert(val == true, fail_msg(val, err))
end
---
tests.is_root_with_non_root_unix_1 = function()
    cfg.arch = "Linux"
    local val, err = sys.is_root("/dir/")
    assert(val == false, fail_msg(val, err))
end
tests.is_root_with_non_root_unix_2 = function()
    cfg.arch = "Linux"
    local val, err = sys.is_root("./")
    assert(val == false, fail_msg(val, err))
end

tests.is_root_with_non_root_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_root("C:\\dir")
    assert(val == false, fail_msg(val, err))
end

tests.is_root_with_non_root_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_root("\\dir\\")
    assert(val == false, fail_msg(val, err))
end

tests.is_root_with_non_root_win_3 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_root(".\\")
    assert(val == false, fail_msg(val, err))
end

--- is_abs()

tests.is_abs_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_abs("/dir1/dir2/file")
    assert(val == true, fail_msg(val, err))
end

tests.is_abs_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_abs("C:\\dir1\\dir2\\file.ext")
    assert(val == true, fail_msg(val, err))
end

tests.is_abs_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_abs("\\dir1\\dir2\\file.ext")
    assert(val == true, fail_msg(val, err))
end
---
tests.is_abs_with_non_abs_unix_1 = function()
    cfg.arch = "Linux"
    local val, err = sys.is_abs("dir1/dir2/file")
    assert(val == false, fail_msg(val, err))
end
tests.is_abs_with_non_abs_unix_2 = function()
    cfg.arch = "Linux"
    local val, err = sys.is_abs("./dir1/dir2/file")
    assert(val == false, fail_msg(val, err))
end

tests.is_abs_with_non_abs_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_abs("dir1\\dir2\\file.ext")
    assert(val == false, fail_msg(val, err))
end

tests.is_abs_with_non_abs_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.is_abs(".\\dir1\\dir2\\file.ext")
    assert(val == false, fail_msg(val, err))
end

--- exists()

tests.exists_dir_os_specific = function()
    cfg.arch = original_arch
    local val, err
    if cfg.arch == "Windows" then
        val, err = sys.exists("C:\\WINDOWS")
    else
        val, err = sys.exists("/bin")
    end
    assert(val == true, fail_msg(val, err))
end
---
tests.exists_root_os_specific = function()
    cfg.arch = original_arch
    local val, err
    if cfg.arch == "Windows" then
        val, err = sys.exists("C:\\")
    else
        val, err = sys.exists("/")
    end
    assert(val == true, fail_msg(val, err))
end
---
tests.exists_this_dir_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.exists(".")
    assert(val == true, fail_msg(val, err))
end

tests.exists_this_dir_win = function()
    cfg.arch = "Windows"
    local val, err = sys.exists(".")
    assert(val == true, fail_msg(val, err))
end
---
tests.exists_nonexistent_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.exists("hopefully_totally_nonexistent_345678")
    assert(val == false and err:find("cannot obtain information from file"), fail_msg(val, err))
end

tests.exists_nonexistent_win = function()
    cfg.arch = "Windows"
    local val, err = sys.exists("hopefully_totally_nonexistent_345679")
    assert(val == false and err:find("cannot obtain information from file"), fail_msg(val, err))
end

--- is_file()

tests.is_file_os_specific = function()
    cfg.arch = original_arch
    local filename = sys.tmp_name("is_file_os_specific--file--")
    assert(io.open(filename, "w"):close())
    local val, err = sys.is_file(filename)
    assert(os.remove(filename))
    assert(val == true, fail_msg(val, err))
end
---
tests.is_file_nonexistent_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_file("hopefully_totally_nonexistent_345688")
    assert(val == false, fail_msg(val, err))
end

tests.is_file_nonexistent_win = function()
    cfg.arch = "Windows"
    local val, err = sys.is_file("hopefully_totally_nonexistent_345689")
    assert(val == false, fail_msg(val, err))
end

--- is_dir()

tests.is_dir_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_dir(".")
    assert(val == true, fail_msg(val, err))
end

tests.is_dir_win = function()
    cfg.arch = "Windows"
    local val, err = sys.is_dir(".")
    assert(val == true, fail_msg(val, err))
end
---
tests.is_dir_nonexistent_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_dir("hopefully_totally_nonexistent_345698")
    assert(val == false, fail_msg(val, err))
end

tests.is_dir_nonexistent_win = function()
    cfg.arch = "Windows"
    local val, err = sys.is_dir("hopefully_totally_nonexistent_345699")
    assert(val == false, fail_msg(val, err))
end

--- current_dir()

tests.current_dir_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.current_dir()
    assert(val == assert(lfs.currentdir()), fail_msg(val, err))
end

--- get_directory()

tests.get_directory_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.get_directory(".")
    assert(type(val) == "function", fail_msg(val, err))
end

tests.get_directory_win = function()
    cfg.arch = "Windows"
    local val, err = sys.get_directory(".")
    assert(type(val) == "function", fail_msg(val, err))
end
---
tests.get_directory_nonexistent_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.get_directory("hopefully_totally_nonexistent_245699")
    assert(val == nil and err:find("not a directory"), fail_msg(val, err))
end

tests.get_directory_nonexistent_win = function()
    cfg.arch = "Windows"
    local val, err = sys.get_directory("hopefully_totally_nonexistent_245699")
    assert(val == nil and err:find("not a directory"), fail_msg(val, err))
end

--- extract_name()

tests.extract_name_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.extract_name("/dir1/dir2/dir3/file")
    assert(val == "file", fail_msg(val, err))
end

tests.extract_name_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.extract_name("C:\\dir1\\dir2\\dir3\\file.ext")
    assert(val == "file.ext", fail_msg(val, err))
end

tests.extract_name_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.extract_name("\\dir1\\dir2\\dir3\\file.ext")
    assert(val == "file.ext", fail_msg(val, err))
end
---
tests.extract_name_with_slash_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.extract_name("/dir1/dir2/dir3/")
    assert(val == "dir3", fail_msg(val, err))
end

tests.extract_name_with_slash_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.extract_name("C:\\dir1\\dir2\\dir3\\")
    assert(val == "dir3", fail_msg(val, err))
end

tests.extract_name_with_slash_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.extract_name("\\dir1\\dir2\\dir3\\")
    assert(val == "dir3", fail_msg(val, err))
end
---
tests.extract_name_with_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.extract_name("/")
    assert(val == "/", fail_msg(val, err))
end

tests.extract_name_with_root_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.extract_name("C:\\")
    assert(val == "C:\\", fail_msg(val, err))
end

tests.extract_name_with_root_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.extract_name("\\")
    assert(val == "\\", fail_msg(val, err))
end

--- parent_dir()

tests.parent_dir_with_file_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parent_dir("/dir1/dir2/file")
    assert(val == "/dir1/dir2", fail_msg(val, err))
end

tests.parent_dir_with_file_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("C:\\dir1\\dir2\\file.ext")
    assert(val == "C:\\dir1\\dir2", fail_msg(val, err))
end
---
tests.parent_dir_with_dir_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parent_dir("/dir1/dir2/dir3/")
    assert(val == "/dir1/dir2", fail_msg(val, err))
end

tests.parent_dir_with_dir_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("C:\\dir1\\dir2\\dir3\\")
    assert(val == "C:\\dir1\\dir2", fail_msg(val, err))
end
---
tests.parent_dir_with_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parent_dir("/")
    assert(val == nil, fail_msg(val, err))
end

tests.parent_dir_with_root_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("C:\\")
    assert(val == nil, fail_msg(val, err))
end
---
tests.parent_dir_with_comma_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parent_dir("/dir1/dir2/dir3/.")
    assert(val == "/dir1/dir2", fail_msg(val, err))
end

tests.parent_dir_with_comma_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("C:\\dir1\\dir2\\dir3\\.")
    assert(val == "C:\\dir1\\dir2", fail_msg(val, err))
end

tests.parent_dir_with_comma_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("\\dir1\\dir2\\dir3\\.")
    assert(val == "\\dir1\\dir2", fail_msg(val, err))
end
---
tests.parent_dir_with_comma_repeat_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parent_dir("/dir1/./dir2/dir3/././.")
    assert(val == "/dir1/dir2", fail_msg(val, err))
end

tests.parent_dir_with_comma_repeat_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("C:\\dir1\\.\\dir2\\dir3\\.\\.\\.")
    assert(val == "C:\\dir1\\dir2", fail_msg(val, err))
end

tests.parent_dir_with_comma_repeat_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir("\\dir1\\.\\dir2\\dir3\\.\\.\\.")
    assert(val == "\\dir1\\dir2", fail_msg(val, err))
end
---
tests.parent_dir_with_preceding_comma_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parent_dir("./dir1/dir2/dir3/")
    assert(val == "./dir1/dir2", fail_msg(val, err))
end

tests.parent_dir_with_preceding_comma_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parent_dir(".\\dir1\\dir2\\dir3\\")
    assert(val == ".\\dir1\\dir2", fail_msg(val, err))
end

--- parents_up_to()

tests.parents_up_to_with_file_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parents_up_to("/dir1/dir2/dir3/file","/dir1")
    assert(val[1] == "/dir1/dir2/dir3" and val[2] == "/dir1/dir2" and val[3] == nil, fail_msg(val, err))
end

tests.parents_up_to_with_file_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parents_up_to("C:\\dir1\\dir2\\dir3\\file","C:\\dir1")
    assert(val[1] == "C:\\dir1\\dir2\\dir3" and val[2] == "C:\\dir1\\dir2" and val[3] == nil, fail_msg(val, err))
end
---
tests.parents_up_to_with_file_and_trailing_separator_in_boundary_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parents_up_to("/dir1/dir2/dir3/file","/dir1/")
    assert(val[1] == "/dir1/dir2/dir3" and val[2] == "/dir1/dir2" and val[3] == nil, fail_msg(val, err))
end

tests.parents_up_to_with_file_and_trailing_separator_in_boundary_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parents_up_to("C:\\dir1\\dir2\\dir3\\file","C:\\dir1\\")
    assert(val[1] == "C:\\dir1\\dir2\\dir3" and val[2] == "C:\\dir1\\dir2" and val[3] == nil, fail_msg(val, err))
end
---
tests.parents_up_to_with_dir_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parents_up_to("/dir1/dir2/dir3/dir4/","/dir1")
    assert(val[1] == "/dir1/dir2/dir3" and val[2] == "/dir1/dir2" and val[3] == nil, fail_msg(val, err))
end

tests.parents_up_to_with_dir_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parents_up_to("C:\\dir1\\dir2\\dir3\\dir4\\","C:\\dir1")
    assert(val[1] == "C:\\dir1\\dir2\\dir3" and val[2] == "C:\\dir1\\dir2" and val[3] == nil, fail_msg(val, err))
end
---
tests.parents_up_to_with_file_and_root_boundary_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parents_up_to("/dir1/dir2/file","/")
    assert(val[1] == "/dir1/dir2" and val[2] == "/dir1" and val[3] == nil, fail_msg(val, err))
end

tests.parents_up_to_with_file_and_root_boundary_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parents_up_to("C:\\dir1\\dir2\\file","C:\\")
    assert(val[1] == "C:\\dir1\\dir2" and val[2] == "C:\\dir1" and val[3] == nil, fail_msg(val, err))
end
---
tests.parents_up_to_with_dir_and_root_boundary_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parents_up_to("/dir1/dir2/dir3/","/")
    assert(val[1] == "/dir1/dir2" and val[2] == "/dir1" and val[3] == nil, fail_msg(val, err))
end

tests.parents_up_to_with_dir_and_root_boundary_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parents_up_to("C:\\dir1\\dir2\\dir3\\","C:\\")
    assert(val[1] == "C:\\dir1\\dir2" and val[2] == "C:\\dir1" and val[3] == nil, fail_msg(val, err))
end
---
tests.parents_up_to_with_comma_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.parents_up_to("/dir1/dir2/./dir3/","/")
    assert(val[1] == "/dir1/dir2" and val[2] == "/dir1" and val[3] == nil, fail_msg(val, err))
end

tests.parents_up_to_with_comma_win = function()
    cfg.arch = "Windows"
    local val, err = sys.parents_up_to("C:\\dir1\\dir2\\.\\dir3\\","C:\\")
    assert(val[1] == "C:\\dir1\\dir2" and val[2] == "C:\\dir1" and val[3] == nil, fail_msg(val, err))
end

--- make_path()

tests.make_path_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.make_path("/this/is","/my/","/little/path")
    assert(val == "/this/is/my/little/path", fail_msg(val, err))
end

tests.make_path_win = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("C:\\this\\is","\\my\\","\\little\\path")
    assert(val == "C:\\this\\is\\my\\little\\path", fail_msg(val, err))
end
---
tests.make_path_with_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.make_path("/")
    assert(val == "/", fail_msg(val, err))
end

tests.make_path_with_root_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("C:\\")
    assert(val == "C:\\", fail_msg(val, err))
end

tests.make_path_with_root_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("\\")
    assert(val == "\\", fail_msg(val, err))
end
---
tests.make_path_with_slash_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.make_path("/this/is","/my/","/little/path/")
    assert(val == "/this/is/my/little/path", fail_msg(val, err))
end

tests.make_path_with_slash_win = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("C:\\this\\is","\\my\\","\\little\\path\\")
    assert(val == "C:\\this\\is\\my\\little\\path", fail_msg(val, err))
end
---
tests.make_path_with_no_part_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.make_path()
    assert(val == assert(lfs.currentdir()), fail_msg(val, err))
end

--- abs_path()

tests.abs_path_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.abs_path("this/is/my/little/path")
    assert(val == assert(lfs.currentdir()) .. "/this/is/my/little/path", fail_msg(val, err))
end

tests.abs_path_win = function()
    cfg.arch = "Windows"
    local val, err = sys.abs_path("this\\is\\my\\little\\path")
    assert(val == assert(lfs.currentdir()) .. "\\this\\is\\my\\little\\path", fail_msg(val, err))
end
---
tests.abs_path_with_abs_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.abs_path("/this/is/my/little/path")
    assert(val == "/this/is/my/little/path", fail_msg(val, err))
end

tests.abs_path_with_abs_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.abs_path("C:\\this\\is\\my\\little\\path")
    assert(val == "C:\\this\\is\\my\\little\\path", fail_msg(val, err))
end

tests.abs_path_with_abs_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.abs_path("\\this\\is\\my\\little\\path")
    assert(val == "\\this\\is\\my\\little\\path", fail_msg(val, err))
end

--- tmp_dir()

tests.tmp_dir_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.tmp_dir()
    assert(type(val) == "string" and val ~= "" and sys.is_abs(val) and sys.exists(val) and sys.is_dir(val) , fail_msg(val, err))
end

--- tmp_name()

tests.tmp_name_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.tmp_name()
    assert(type(val) == "string" and val ~= "" and sys.is_abs(val) and not sys.exists(val) , fail_msg(val, err))
end

--- get_file_list()

tests.get_file_list_os_specific = function()
    cfg.arch = original_arch

    -- create directory and files within
    local dir = sys.tmp_name("get_file_list_os_specific--dir--")
    local file1 = sys.make_path(dir, "file1")
    local file2 = sys.make_path(dir, "file2")
    assert(lfs.mkdir(dir))
    assert(io.open(file1, "w"):close())
    assert(io.open(file2, "w"):close())

    -- get the file list
    local val, err = sys.get_file_list(dir)

    -- clean
    assert(os.remove(file1))
    assert(os.remove(file2))
    assert(lfs.rmdir(dir))

    -- verify
    assert(val[1] == sys.extract_name(file1) and val[2] == sys.extract_name(file2) or
           val[1] == sys.extract_name(file2) and val[2] == sys.extract_name(file1), fail_msg(val, err))
end
---
tests.get_file_list__with_empty_dir_os_specific = function()
    cfg.arch = original_arch

    -- create a directory
    local dir = sys.tmp_name("get_file_list__with_empty_dir_os_specific--dir--")
    assert(lfs.mkdir(dir))

    -- get the file list
    local val, err = sys.get_file_list(dir)

    -- clean
    assert(lfs.rmdir(dir))

    -- verify
    assert(type(val) == "table" and #val == 0, fail_msg(val, err))
end

--- change_dir()

tests.change_dir_os_specific = function()
    cfg.arch = original_arch

    -- set and remember the directories
    local orig = assert(lfs.currentdir())
    local future = assert(sys.parent_dir(assert(lfs.currentdir())))

    -- change the directory and record the change
    local val, err = sys.change_dir(future)
    local new = assert(lfs.currentdir())

    -- change back to the original directory
    assert(lfs.chdir(orig))
    assert(lfs.currentdir() == orig)

    -- verify
    assert(val == true and err == orig and new == future, fail_msg(val, err))
end

--- make_dir()

tests.make_dir_os_specific = function()
    cfg.arch = original_arch

    -- create the dir
    local dir = sys.tmp_name("make_dir_os_specific--dir--")
    local val, err = sys.make_dir(dir)

    -- verify
    assert(val == true and sys.exists(dir) , fail_msg(val, err))

    -- clean
    assert(lfs.rmdir(dir))
end

--- move_to()

tests.move_to_with_file_os_specific = function()
    cfg.arch = original_arch

    -- create a file
    local file = sys.tmp_name("make_dir_os_specific--file--")
    assert(io.open(file, "w"):close())

    -- create a dir
    local dir = sys.tmp_name("make_dir_os_specific--dir--")
    assert(sys.make_dir(dir))

    -- move the file to the dir
    local val, err = sys.move_to(file, dir)

    -- verify
    local moved_file = sys.make_path(dir, sys.extract_name(file))
    assert(val == true and not sys.exists(file) and sys.exists(moved_file) , fail_msg(val, err))

    -- clean
    assert(os.remove(moved_file))
    assert(lfs.rmdir(dir))
end
---
tests.move_to_with_dir_os_specific = function()
    cfg.arch = original_arch

    -- create a source dir
    local src_dir = sys.tmp_name("move_to_with_dir_os_specific--src-dir--")
    assert(sys.make_dir(src_dir))

    -- create a file within
    local file = sys.make_path(src_dir, "file")
    assert(io.open(file, "w"):close())

    -- create a destination dir
    local dest_dir = sys.tmp_name("move_to_with_dir_os_specific--dest-dir--")
    assert(sys.make_dir(dest_dir))

    -- move the source directory to the destination directory (should be recursive)
    local val, err = sys.move_to(src_dir, dest_dir)

    -- verify
    local moved_dir = sys.make_path(dest_dir, sys.extract_name(src_dir))
    local moved_file = sys.make_path(moved_dir, sys.extract_name(file))
    assert(val == true and not sys.exists(src_dir)
                       and not sys.exists(file)
                       and sys.exists(moved_dir)
                       and sys.exists(moved_file) , fail_msg(val, err))

    -- clean
    assert(os.remove(moved_file))
    assert(lfs.rmdir(moved_dir))
    assert(lfs.rmdir(dest_dir))
end

--- rename()

tests.rename_with_file_os_specific = function()
    cfg.arch = original_arch

    -- create a file
    local file = sys.tmp_name("rename_with_file_os_specific--file-original--")
    assert(io.open(file, "w"):close())

    -- rename the file
    local renamed_file = sys.tmp_name("rename_with_file_os_specific--file-renamed--")
    local val, err = sys.rename(file, renamed_file)

    -- verify
    assert(val == true and not sys.exists(file) and sys.exists(renamed_file) , fail_msg(val, err))

    -- clean
    assert(os.remove(renamed_file))
end
---
tests.rename_with_dir_os_specific = function()
    cfg.arch = original_arch

    -- create a dir
    local dir = sys.tmp_name("rename_with_dir_os_specific--dir-original--")
    assert(sys.make_dir(dir))

    -- create a file within
    local file = sys.make_path(dir, "file")
    assert(io.open(file, "w"):close())

    -- rename the directory
    local renamed_dir = sys.tmp_name("rename_with_dir_os_specific--dir-renamed--")
    local val, err = sys.rename(dir, renamed_dir)

    -- verify
    local renamed_file = sys.make_path(renamed_dir, sys.extract_name(file))
    assert(val == true and not sys.exists(dir)
                       and not sys.exists(file)
                       and sys.exists(renamed_dir)
                       and sys.exists(renamed_file) , fail_msg(val, err))

    -- clean
    assert(os.remove(renamed_file))
    assert(lfs.rmdir(renamed_dir))
end

--- copy()

tests.copy_with_file_os_specific = function()
    cfg.arch = original_arch

    -- create a file
    local file = sys.tmp_name("copy_with_file_os_specific--file--")
    assert(io.open(file, "w"):close())

    -- create a dir
    local dir = sys.tmp_name("copy_with_file_os_specific--src-dir--")
    assert(sys.make_dir(dir))

    -- copy the file to the dir
    local val, err = sys.copy(file, dir)

    -- verify
    local copied_file = sys.make_path(dir, sys.extract_name(file))
    assert(val == true and sys.exists(file) and sys.exists(copied_file) , fail_msg(val, err))

    -- clean
    assert(os.remove(file))
    assert(os.remove(copied_file))
    assert(lfs.rmdir(dir))
end
---
tests.copy_with_dir_os_specific = function()
    cfg.arch = original_arch

    -- create a source dir
    local src_dir = sys.tmp_name("copy_with_dir_os_specific--src-dir--")
    assert(sys.make_dir(src_dir))

    -- create a file within
    local file = sys.make_path(src_dir, "file")
    assert(io.open(file, "w"):close())

    -- create a destination dir
    local dest_dir = sys.tmp_name("copy_with_dir_os_specific--dest-dir--")
    assert(sys.make_dir(dest_dir))

    -- copy the source directory to the destination directory (should be recursive)
    local val, err = sys.copy(src_dir, dest_dir)

    -- verify
    local copied_dir = sys.make_path(dest_dir, sys.extract_name(src_dir))
    local copied_file = sys.make_path(copied_dir, sys.extract_name(file))
    assert(val == true and sys.exists(src_dir)
                       and sys.exists(file)
                       and sys.exists(copied_dir)
                       and sys.exists(copied_file) , fail_msg(val, err))

    -- clean
    assert(os.remove(file))
    assert(lfs.rmdir(src_dir))
    assert(os.remove(copied_file))
    assert(lfs.rmdir(copied_dir))
    assert(lfs.rmdir(dest_dir))
end

--- delete()

tests.delete_with_file_os_specific = function()
    cfg.arch = original_arch

    -- create a file
    local file = sys.tmp_name("delete_with_file_os_specific--file--")
    assert(io.open(file, "w"):close())

    -- delete the file
    local val, err = sys.delete(file)

    -- verify
    assert(val == true and not sys.exists(file) , fail_msg(val, err))
end
---
tests.delete_with_empty_dir_os_specific = function()
    cfg.arch = original_arch

    -- create a dir
    local dir = sys.tmp_name("delete_with_empty_dir_os_specific--dir--")
    assert(sys.make_dir(dir))

    -- delete the dir
    local val, err = sys.delete(dir)

    -- verify
    assert(val == true and not sys.exists(dir) , fail_msg(val, err))
end
---
tests.delete_with_nonempty_dir_os_specific = function()
    cfg.arch = original_arch

    -- create a dir
    local dir = sys.tmp_name("delete_with_nonempty_dir_os_specific--dir--")
    assert(sys.make_dir(dir))

    -- create a file within
    local file = sys.make_path(dir, "file")
    assert(io.open(file, "w"):close())

    -- delete the dir
    local val, err = sys.delete(dir)

    -- verify
    assert(val == true and not sys.exists(file) and not sys.exists(dir) , fail_msg(val, err))
end
---
tests.delete_with_nonexistent_path_os_specific = function()
    cfg.arch = original_arch

    -- construct a nonexistent path
    local nonexistent_path = sys.tmp_name("delete_with_nonexistent_path_os_specific--nonexistent-path")
    assert(not sys.exists(nonexistent_path))

    -- attempt to delete the path (should just return true)
    local val, err = sys.delete(nonexistent_path)

    -- verify
    assert(val == true , fail_msg(val, err))
end
---
tests.delete_with_non_absolute_path_os_specific = function()
    cfg.arch = original_arch

    -- construct a non absolute path
    local nonabs_path = "not-abs-895454-" .. utils.rand(1000000)

    -- attempt to delete the path (should throw an assertion error)
    local val, err = pcall(sys.delete, nonabs_path)

    -- verify
    assert(val == false and err:find("not an absolute path") , fail_msg(val, err))
end


-- actually run the test suite
run_tests(tests)

-- set the original system architecture back (DO NOT REMOVE!)
cfg.arch = original_arch
