-- Tests of LuaDist's dependency resolving

local depends = require "dist.depends"

-- Return string describing packages and versions in 'pkgs' table, separated by space.
-- e.g.: "luadist-1.2 coxpcall-0.4 luafilesystem 0.3"
-- If 'pkgs' is nil, return nil.
local function describe_packages(pkgs)

    if not pkgs then return nil end

    assert(type(pkgs) == "table", "depends.get_packages_to_install: Argument 'pkgs' is not a table.")

    local str = ""

    for k,v in ipairs(pkgs) do
        if k == 1 then
            str = str .. v.name .. "-" .. v.version
        else
            str = str .. " " .. v.name .. "-" .. v.version
        end
    end

    return str
end

local function pkgs_fail_msg(pkgs)
    if not pkgs then
        return "TEST FAILED!!! - Returned packages were: 'nil'."
    else
        return "TEST FAILED!!! - Returned packages were: '" .. describe_packages(pkgs) .. "'."
    end
end


-- Test suite.
local tests = {}


-- TODO add tests with the order of packages to install reversed


--- ========== DEPENDENCY RESOLVING ==========

--- === DEPENDS ===

--- normal dependencies

-- a depends b, install a
tests.depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs))
end

-- a depends b, b depends c, install a
tests.depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest);
    assert(describe_packages(pkgs) == "c-scm b-scm a-scm", pkgs_fail_msg(pkgs))
end

-- a depends b, a depends c, a depends d, c depends f, c depends g, d depends c,
-- d depends e, d depends j, e depends h, e depends i, g depends l, j depends k,
-- install a
tests.depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b", "c", "d"}}
    manifest.b = {name="b", version="scm",}
    manifest.c = {name="c", version="scm", depends={"f", "g"}}
    manifest.d = {name="d", version="scm", depends={"c", "e", "j"}}
    manifest.e = {name="e", version="scm", depends={"h", "i"}}
    manifest.f = {name="f", version="scm",}
    manifest.g = {name="g", version="scm", depends={"l"}}
    manifest.h = {name="h", version="scm",}
    manifest.i = {name="i", version="scm",}
    manifest.j = {name="j", version="scm", depends={"k"}}
    manifest.k = {name="k", version="scm",}
    manifest.l = {name="l", version="scm",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm f-scm l-scm g-scm c-scm h-scm i-scm e-scm k-scm j-scm d-scm a-scm", pkgs_fail_msg(pkgs))
end


--- circular dependencies

-- a depends b, b depends a, install a
tests.depends_circular_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b-scm"}}
    manifest.b = {name="b", version="scm", depends={"a-scm"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a depends b, b depends a, install a + b
tests.depends_circular_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", depends={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a depends b, b depends c, c depends a, install a
tests.depends_circular_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", depends={"a"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a depends b, b depends c, c depends d, d depends e, e depends b, install a
tests.depends_circular_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm", depends={"e"}}
    manifest.e = {name="e", version="scm", depends={"b"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- === CONFLICTS ===

--- conflicts with installed  package

-- a installed, a conflicts b, install b
tests.conflicts_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", conflicts={"b"}}
    manifest.b = {name="b", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a installed, b conflicts a, install b
tests.conflicts_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm",}
    manifest.b = {name="b", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a installed, b conflicts a, a conflicts b, install b
tests.conflicts_with_installed_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", conflicts={"b"}}
    manifest.b = {name="b", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- conflicts with another package to install

-- a conflicts b, install a + b
tests.conflicts_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", conflicts={"b"}}
    manifest.b = {name="b", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- b conflicts a, install a + b
tests.conflicts_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm",}
    manifest.b = {name="b", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- b conflicts a, a conflicts b, install a + b
tests.conflicts_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", conflicts={"b"}}
    manifest.b = {name="b", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- === CONFLICTS + DEPENDS ===

--- conflicts of dependencies with installed package

-- a installed, b depends c, a conflicts c, install b
tests.conflicts_and_depends_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", conflicts={"c"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a installed, b depends c, c conflicts a, install b
tests.conflicts_and_depends_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm",}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- conflicts of dependencies with another package to install

-- a depends b, b conflicts c, install a + c
tests.conflicts_and_depends_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", conflicts={"c"}}
    manifest.c = {name="c", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a depends b, c conflicts b, install a + c
tests.conflicts_and_depends_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm",}
    manifest.c = {name="c", version="scm", conflicts={"b"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- === PROVIDES ===

--- direct provides with installed package

-- a installed, a provides b, install b
tests.provides_direct_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "", pkgs_fail_msg(pkgs))
end

-- a installed, b provides a, install b
tests.provides_direct_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm",}
    manifest.b = {name="b", version="scm", provides={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- direct provides with package to install

-- TODO: When dealing with this situation, luadist-git finds that a can be installed
--       so it adds 'a' to the packages to install an then when checking the 'b' package,
--       it treats 'a' as being installed, so it simply skips the 'b' package.
--       Implement this in such a way that the user will be warned that he was
--       trying to install two incompatible packages?
-- a provides b, install a + b
--[[
tests.provides_direct_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end
--]]

-- b provides a, install a + b
tests.provides_direct_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm",}
    manifest.b = {name="b", version="scm", provides={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- the same provides with installed package

-- a installed, a provides c, b provides c, install b
tests.provides_same_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}}
    manifest.b = {name="b", version="scm", provides={"c"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

--- the same provides with package to install

-- a provides c, b provides c, install a + b
tests.provides_same_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}}
    manifest.b = {name="b", version="scm", provides={"c"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- === PROVIDES + DEPENDS ===

--- direct provides with dependencies and installed package

-- a installed, a provides c, b depends c, install b
tests.provides_direct_and_depends_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm", pkgs_fail_msg(pkgs))
end

-- a installed, b depends c, c provides a, install b
tests.provides_direct_and_depends_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm",}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", provides={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- direct provides with dependencies and package to install

-- a provides c, b depends c, install a + b
tests.provides_direct_and_depends_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "a-scm b-scm", pkgs_fail_msg(pkgs))
end

-- TODO: To make luadist-git find the solution in this situation, it would have
--       to try all possible permutations of packages to install (e.g. reversed)
--       or use some logic engine. Implement it?
-- a depends c, b provides c, install a + b
--[[
tests.provides_direct_and_depends_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"c"}}
    manifest.b = {name="b", version="scm", provides={"c"}}
    manifest.c = {name="c", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    print(err)
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs))
end
--]]


--- the same provides with dependencies and installed package

-- a installed, a provides d, b depends c, c provides d, install b
tests.provides_same_and_depends_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"d"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", provides={"d"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- the same provides with dependencies and package to install

-- a depends b, b provides d, c provides d, install a + c
tests.provides_same_and_depends_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", provides={"d"}}
    manifest.c = {name="c", version="scm", provides={"d"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a provides d, b depends c, c provides d, install a + b
tests.provides_same_and_depends_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"d"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", provides={"d"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a depends b, b provides e, c depends d, d provides e, install a + c
tests.provides_same_and_depends_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", provides={"e"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm", provides={"e"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- === PROVIDES + CONFLICTS ===

--- direct provides with conflicts and package to install

-- a provides b, b conflicts c, install a + c
tests.provides_direct_and_conflicts_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm", conflicts={"c"}}
    manifest.c = {name="c", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == "a-scm c-scm", pkgs_fail_msg(pkgs))
end

-- a provides b, b conflicts c, install c + a
tests.provides_direct_and_conflicts_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm", conflicts={"c"}}
    manifest.c = {name="c", version="scm",}

    local pkgs, err = depends.get_depends({'c', 'a'}, installed, manifest);
    assert(describe_packages(pkgs) == "c-scm a-scm", pkgs_fail_msg(pkgs))
end

-- a provides b, c conflicts b, install a + c
tests.provides_direct_and_conflicts_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm",}
    manifest.c = {name="c", version="scm", conflicts={"b"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a provides b, c conflicts b, install c + a
tests.provides_direct_and_conflicts_with_to_install_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm",}
    manifest.c = {name="c", version="scm", conflicts={"b"}}

    local pkgs, err = depends.get_depends({'c', 'a'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- direct provides with conflicts and installed package

-- a installed, a provides b, b conflicts c, install c
tests.provides_direct_and_conflicts_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm", conflicts={"c"}}
    manifest.c = {name="c", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'c'}, installed, manifest);
    assert(describe_packages(pkgs) == "c-scm", pkgs_fail_msg(pkgs))
end

-- a installed, a provides b, c conflicts b, install c
tests.provides_direct_and_conflicts_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm",}
    manifest.c = {name="c", version="scm", conflicts={"b"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end


--- === PROVIDES + DEPENDS + CONFLICTS ===

--- direct provides with dependencies + conflicts and installed package

-- a installed, a provides d, b depends c, c conflicts d, install b
tests.provides_direct_depends_and_conflicts_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"d"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", conflicts={"d"}}
    manifest.d = {name="d", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a installed, a conflicts d, b depends c, c provides d, install b
tests.provides_direct_depends_and_conflicts_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", conflicts={"d"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", provides={"d"}}
    manifest.d = {name="d", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a installed, a provides c, b depends c, c depends d, d conflicts a, install b
tests.provides_direct_depends_and_conflicts_with_installed_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm", pkgs_fail_msg(pkgs))
end

-- a installed, a provides c, a conflicts d, b depends c, c depends d, install b
tests.provides_direct_depends_and_conflicts_with_installed_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}, conflicts={"d"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm", pkgs_fail_msg(pkgs))
end

-- a installed, a provides b, b depends c, d conflicts c, install c
tests.provides_direct_depends_and_conflicts_with_installed_5 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"b"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm",}
    manifest.d = {name="d", version="scm", conflicts={"c"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'c'}, installed, manifest);
    assert(describe_packages(pkgs) == "c-scm", pkgs_fail_msg(pkgs))
end

--- direct provides with dependencies + conflicts and package to install

-- a provides c, b depends c, c depends d, d conflicts a, install a + b
tests.provides_direct_depends_and_conflicts_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "a-scm b-scm", pkgs_fail_msg(pkgs))
end

-- a provides c, a conflicts d, b depends c, c depends d, install a + b
tests.provides_direct_depends_and_conflicts_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", provides={"c"}, conflicts={"d"}}
    manifest.b = {name="b", version="scm", depends={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "a-scm b-scm", pkgs_fail_msg(pkgs))
end


-- TODO: Non-standard situation so luadist-git cannot find the solution. Implement it?
-- b provides c, a depends c, c depends d, d conflicts a, install a + b
--[[
tests.provides_direct_depends_and_conflicts_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"c"}}
    manifest.b = {name="b", version="scm", provides={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs))
end
--]]

-- TODO: Non-standard situation so luadist-git cannot find the solution. Implement it?
-- b provides c, a depends c, c depends d, a conflicts d, install a + b
--[[
tests.provides_direct_depends_and_conflicts_with_to_install_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"c"}, conflicts={"a"}}
    manifest.b = {name="b", version="scm", provides={"c"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm"}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs))
end
--]]

-- a depends b, b provides e, c depends d, d conflicts e, install a + c
tests.provides_direct_depends_and_conflicts_with_to_install_5 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", provides={"e"}}
    manifest.c = {name="c", version="scm", depends={"d"}}
    manifest.d = {name="d", version="scm", conflicts={"e"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest);
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs))
end

-- a depends b, b provides c, d depends e, e provides f, f conflicts c, install a + d
tests.provides_direct_depends_and_conflicts_with_to_install_6 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", provides={"c"}}
    manifest.c = {name="c", version="scm",}
    manifest.d = {name="d", version="scm", depends={"e"}}
    manifest.e = {name="e", version="scm", provides={"f"}}
    manifest.f = {name="f", version="scm", conflicts={"c"}}

    local pkgs, err = depends.get_depends({'a', 'd'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm a-scm e-scm d-scm", pkgs_fail_msg(pkgs))
end

-- a depends b, b provides c, c conflicts f, d depends e, e provides f, install a + d
tests.provides_direct_depends_and_conflicts_with_to_install_7 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", version="scm", depends={"b"}}
    manifest.b = {name="b", version="scm", provides={"c"}}
    manifest.c = {name="c", version="scm", conflicts={"f"}}
    manifest.d = {name="d", version="scm", depends={"e"}}
    manifest.e = {name="e", version="scm", provides={"f"}}
    manifest.f = {name="f", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'd'}, installed, manifest);
    assert(describe_packages(pkgs) == "b-scm a-scm e-scm d-scm", pkgs_fail_msg(pkgs))
end

--- === REPLACES ===

-- 'replaces' relationship hasn't been implemented in luadist-git yet


--- ========== VERSION RESOLVING =============

-- TODO add version tests

-- Run all the tests.
for _, test in pairs(tests) do test() end
