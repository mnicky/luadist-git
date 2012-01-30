-- System functions

module ("dist.utils", package.seeall)

-- Returns a deep copy of 'table' with reference to the same metadata table.
-- Source: http://lua-users.org/wiki/CopyTable
function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- Return deep copy of table 'array', containing only items for which 'predicate_fn' returns true.
function filter(array, predicate_fn)
    assert(type(array) == "table", "utils.filter: Argument 'array' is not a table.")
    assert(type(predicate_fn) == "function", "utils.filter: Argument 'predicate_fn' is not a function.")
    local tbl = {}
    for _,v in pairs(array) do
        if predicate_fn(v) == true then table.insert(tbl, deepcopy(v)) end
    end
    return tbl
end

-- Return deep copy of table 'array', sorted according to the 'compare_fn' function.
function sort(array, compare_fn)
    assert(type(array) == "table", "utils.sort: Argument 'array' is not a table.")
    assert(type(compare_fn) == "function", "utils.sort: Argument 'compare_fn' is not a function.")
    local tbl = deepcopy(array)
    table.sort(tbl, compare_fn)
    return tbl
end
