require("lua-utils")

local function find(tbl, elem, offset)
  for i = offset, #tbl do
    if tbl[i] == elem then
      return i
    end
  end
end

local function findall(haystack, needle, pos, offset)
  offset = offset or 0
  local ind = find(haystack, needle, offset)

  if not ind then
    return pos
  end

  pos = pos or {}
  pos[#pos + 1] = ind

  return findall(haystack, needle, pos, ind + 1)
end

local function errfmt(s, switch, ...)
  s = "%s: " .. s
  error(s:format(switch.name, ...))
end

local function default_switch(short, long, overrides)
  local result = {
    pos = false,
    args = false,
    required = false,
    multiple = true,
    nargs = "+",
    deps = false,
    undeps = false,
    post = false,
    assert = false,
    help = false,
    name = false,
  }

  for key, value in pairs(overrides or {}) do
    result[key] = value
  end

  result.name = long and long or short
  result[1] = short
  result[2] = long

  return result
end

local function find_switch(haystack, switch)
  local long_pos, short_pos
  long_pos = switch[2] and findall(haystack, "--" .. switch[2])
  short_pos = switch[1] and findall(haystack, "-" .. switch[1])

  if switch.required and not long_pos and not short_pos then
    errfmt("required switch not provided", switch)
  end

  local nargs = switch.nargs
  if (not switch.multiple) and (long_pos and short_pos or (#long_pos > 1 or #short_pos > 1)) then
    errfmt("multiple switch instances not allowed (required nargs: %s)", switch, nargs)
  end

  collected = collected or {}
  if long_pos then
    for i = 1, #long_pos do
      collected[#collected + 1] = default_switch(switch[1], switch[2], switch)
      local x = collected[#collected]
      x.pos = long_pos[i]
      x.name = switch[2]
    end
  end

  if short_pos then
    for i = 1, #short_pos do
      collected[#collected + 1] = default_switch(switch[1], switch[2], switch)
      collected[#collected].pos = short_pos[i]
      local x = collected[#collected]
      x.pos = short_pos[i]
      x.name = switch[1]
    end
  end

  return collected
end

local function find_switches(haystack, switches)
  local results = {}

  for i = 1, #switches do
    local ok = find_switch(haystack, switches[i])
    for j = 1, #ok do
      results[#results + 1] = ok[j]
    end
  end

  table.sort(results, function(x, y)
    return x.pos < y.pos
  end)

  return results
end

local function slicelist(x, from, till)
  local out = {}

  for i = from + 1, till - 1 do
    out[#out + 1] = x[i]
  end

  return out
end

--- excludes last switch
local function extract_args(haystack, switches, len, i)
  len = len or #switches
  i = i or 1

  if len == i then
    switches[i].args = slicelist(haystack, switches[i].pos, #haystack + 1)
    return switches
  end

  local first = switches[i]
  local second = switches[i + 1]
  local args = slicelist(haystack, first.pos, second.pos)
  first.args = args

  return extract_args(haystack, switches, len, i + 1)
end

local function collapse(switches)
  local res = {}
  local len = #switches

  for i = 1, len do
    local x = switches[i]
    local use = x[2] or x.name
    local new

    if not res[use] then
      res[use] = default_switch(x[1], x[2], x)
      new = res[use]
      new.args = {}
      new.pos = nil
    else
      new = res[use]
    end

    for j = 1, #x.args do
      new.args[#new.args + 1] = x.args[j]
    end

    if len == i then
      res.__last = new
    end
  end

  return res
end

local function extract_positional(haystack, switches)
  local last = switches.__last
  local positional = {}

  ---
  -- pass
  --
  switches.__last = nil
  return positional, switches
end

local function verify(switches)
  --- check nargs and run assert
end

local function fullhelp(switches)
end

local function optparser()
  local parser = {switches = {}}

  function parser:add(short, long, specs)
  end

  return parser
end

local haystack = split("--switch 1 2 3 -x 2 -x 3 -x 4 -x 6", " ")
local x = default_switch("x", "switch")
local parsed = find_switches(haystack, { x })
extract_args(haystack, parsed)
pp(collapse(parsed))



return optparser
