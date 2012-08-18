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
tests.is_root_with_non_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_root("/dir/")
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
tests.is_abs_with_non_abs_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.is_abs("dir1/dir2/file")
    assert(val == false, fail_msg(val, err))
end

tests.is_abs_with_non_abs_win = function()
    cfg.arch = "Windows"
    local val, err = sys.is_abs("dir1\\dir2\\file.ext")
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

tests.is_file_unix = function()
    cfg.arch = "Linux"
    local filename = assert(os.tmpname())
    assert(io.open(filename, "w"):close())
    local val, err = sys.is_file(filename)
    assert(os.remove(filename))
    assert(val == true, fail_msg(val, err))
end

tests.is_file_win = function()
    cfg.arch = "Windows"
    local filename = assert(os.tmpname())
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

--- make_path()

tests.make_path_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.make_path("/this/is","/my/","/little/path")
    assert(val == "/this/is/my/little/path" , fail_msg(val, err))
end

tests.make_path_win = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("C:\\this\\is","\\my\\","\\little\\path")
    assert(val == "C:\\this\\is\\my\\little\\path" , fail_msg(val, err))
end
---
tests.make_path_with_root_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.make_path("/")
    assert(val == "/" , fail_msg(val, err))
end

tests.make_path_with_root_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("C:\\")
    assert(val == "C:\\" , fail_msg(val, err))
end

tests.make_path_with_root_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("\\")
    assert(val == "\\" , fail_msg(val, err))
end
---
tests.make_path_with_slash_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.make_path("/this/is","/my/","/little/path/")
    assert(val == "/this/is/my/little/path" , fail_msg(val, err))
end

tests.make_path_with_slash_win = function()
    cfg.arch = "Windows"
    local val, err = sys.make_path("C:\\this\\is","\\my\\","\\little\\path\\")
    assert(val == "C:\\this\\is\\my\\little\\path" , fail_msg(val, err))
end
---
tests.make_path_with_no_part_os_specific = function()
    cfg.arch = original_arch
    local val, err = sys.make_path()
    assert(val == assert(lfs.currentdir()) , fail_msg(val, err))
end

--- abs_path()

tests.abs_path_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.abs_path("this/is/my/little/path")
    assert(val == assert(lfs.currentdir()) .. "/this/is/my/little/path" , fail_msg(val, err))
end

tests.abs_path_win = function()
    cfg.arch = "Windows"
    local val, err = sys.abs_path("this\\is\\my\\little\\path")
    assert(val == assert(lfs.currentdir()) .. "\\this\\is\\my\\little\\path" , fail_msg(val, err))
end
---
tests.abs_path_with_abs_unix = function()
    cfg.arch = "Linux"
    local val, err = sys.abs_path("/this/is/my/little/path")
    assert(val == "/this/is/my/little/path" , fail_msg(val, err))
end

tests.abs_path_with_abs_win_1 = function()
    cfg.arch = "Windows"
    local val, err = sys.abs_path("C:\\this\\is\\my\\little\\path")
    assert(val == "C:\\this\\is\\my\\little\\path" , fail_msg(val, err))
end

tests.abs_path_with_abs_win_2 = function()
    cfg.arch = "Windows"
    local val, err = sys.abs_path("\\this\\is\\my\\little\\path")
    assert(val == "\\this\\is\\my\\little\\path" , fail_msg(val, err))
end

--- get_file_list()

tests.get_file_list_os_specific = function()
    cfg.arch = original_arch

    local tmpfile = assert(os.tmpname())
    assert(io.open(tmpfile, "w"):close())
    assert(os.remove(tmpfile))

    local tmpdir = sys.parent_dir(tmpfile)
    local dir = sys.make_path(tmpdir, "dir-957834-" .. utils.rand(1000000))
    local file1 = sys.make_path(dir, "file1-235689-" .. utils.rand(1000000))
    local file2 = sys.make_path(dir, "file2-897452-" .. utils.rand(1000000))

    assert(sys.make_dir(dir))
    assert(io.open(file1, "w"):close())
    assert(io.open(file2, "w"):close())
    local val, err = sys.get_file_list(dir)

    assert(os.remove(file1))
    assert(os.remove(file2))
    assert(lfs.rmdir(dir))
    assert(val[1] == sys.extract_name(file1) and val[2] == sys.extract_name(file2) or
           val[1] == sys.extract_name(file2) and val[2] == sys.extract_name(file1) , fail_msg(val, err))
end
---
tests.get_file_list__with_empty_dir_os_specific = function()
    cfg.arch = original_arch

    local tmpfile = assert(os.tmpname())
    assert(io.open(tmpfile, "w"):close())
    assert(os.remove(tmpfile))

    local tmpdir = sys.parent_dir(tmpfile)
    local dir = sys.make_path(tmpdir, "dir-324687-" .. utils.rand(1000000))

    assert(sys.make_dir(dir))
    local val, err = sys.get_file_list(dir)
    assert(lfs.rmdir(dir))
    assert(type(val) == "table" and #val == 0 , fail_msg(val, err))
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
    assert(val == true and err == orig and new == future , fail_msg(val, err))
end


--- make_dir()
--- move_to()
--- rename()
--- copy()
--- delete()



-- actually run the test suite
run_tests(tests)

-- set the original system architecture back (DO NOT REMOVE!)
cfg.arch = original_arch
