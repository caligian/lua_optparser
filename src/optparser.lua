require("lua-utils")

local function appendlist(x, elems)
  local n = #x

  for i = 1, #elems do
    x[n + i] = elems[i]
  end
end

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
    nargs = "*",
    deps = false,
    undeps = false,
    post = false,
    assert = false,
    help = false,
    name = false,
    metavar = false,
  }

  for key, value in pairs(overrides or {}) do
    result[key] = value
  end

  result[1] = short
  result[2] = long
  result.name = long and long or short

  local metavar = result.metavar or result.name:upper()

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

  local collected = {}
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
    appendlist(results, ok)
  end

  table.sort(results, function(x, y)
    return x.pos < y.pos
  end)

  return results
end

local function slicelist(x, from, till)
  local out = {}

  for i = from, till - 1 do
    out[#out + 1] = x[i]
  end

  return out
end

--- excludes last switch
local function extract_args(haystack, switches, len, i)
  len = len or #switches
  i = i or 1

  if len == i then
    switches[i].args = slicelist(haystack, switches[i].pos + 1, #haystack + 1)
    return switches
  end

  local first = switches[i]
  local second = switches[i + 1]
  local args = slicelist(haystack, first.pos + 1, second.pos)
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
    local nargs = x.nargs

    if not res[use] then
      res[use] = default_switch(x[1], x[2], x)
      new = res[use]
      new.args = {}
    else
      new = res[use]
    end

    local args = new.args
    local passed = #args
    local is_one_or_zero = nargs == "?"
    local is_num = type(nargs) == "number"
    local wrong_nargs = (is_one_or_zero and passed > 1) or (is_num and passed > nargs)

    if wrong_nargs then
      errfmt("required nargs: %s, got %d", new, nargs, passed)
    end

    appendlist(args, x.args)

    if len == i then
      res.__last = new
    elseif i == 1 then
      res.__first = new
    end
  end

  return res
end

local function get_positional_and_keyword(haystack, switches)
  local fulllen = #haystack
  local last = switches.__last
  local first = switches.__first
  local last_pos = last.pos
  local first_pos = first.pos
  local first_args = first.args
  local before_first = first_pos > 1 and slicelist(haystack, 1, first_pos)
  local last_args = last.args
  local last_nargs = last.nargs
  local last_passed_nargs = #last_args
  local sep = find(last_args, "--", last_pos)
  local after_sep = sep and slicelist(last_args, sep + 1, last_passed_nargs)
  local positional = {}
  switches.__last = nil
  switches.__first = nil

  if before_first then
    appendlist(positional, before_first)
  end

  --- last switch
  local is_num = type(last_nargs) == "number"
  local ok = (last_nargs == "+" and last_passed_nargs > 0)
    or (is_num and last_nargs == last_passed_nargs)
    or true
  local function fail()
    errfmt("required nargs: %s, got %d", last, last_nargs, last_passed_nargs)
  end

  if not ok then
    if is_num then
      if last_nargs - last_passed_nargs < 0 then
        fail()
      else
        last_args = slicelist(last_args, 1, last_nargs + 1)
        appendlist(positional, slicelist(last_args, last_nargs + 1, fulllen + 1))
      end
    else
      fail()
    end
  end

  if after_sep then
    appendlist(positional, after_sep)
  end

  switches[last.name] = last
  switches[first.name] = first

  return positional, switches
end

local function parse_args(haystack, positional_spec, keyword_spec)
  local positional, keyword = get_positional_and_keyword(haystack, keyword_spec)
  local results = {}

  -- post-process positional, keyword

  return results
end

local function help(positional_spec, keyword_spec)
  --- gen help
  return text
end

local function optparser(haystack)
  haystack = haystack or arg
  local parser = { switches = { positional = {}, keyword = {} } }
  local pos, kv = parser.switches.positional, parser.switches.keyword

  local function add(switch, positional)
    if positional then
      pos[#pos+1] = switch
    else
      kv[#kv+1] = switch
    end
  end

  function parser:append(name, specs)
    add(default_switch(name, nil, specs), true)
  end

  function parser:on(short, long, specs) 
    add(default_switch(short, long, specs))
  end

  function parser:parse()
    return parse_args(haystack, pos, kv)
  end

  function parser:help()
    return help(pos, kv)
  end

  function parser:print()
    print(help(pos, kv))
  end

  if find(haystack, '--help') then
    parser:print()
    os.exit(0, true)
  end

  return parser
end

local function test()
  local haystack = split("1 2 3 4 --x_switch 1 2 3 -x 2 -x 3 -x 4 -x 6 -y 1 2 3 4 -y -1", " ")
  local x = default_switch("x", "x_switch")
  local y = default_switch("y", "y_switch")
  local parsed = find_switches(haystack, { x, y })

  extract_args(haystack, parsed)

  parsed = collapse(parsed)
  local pos, kv
  pos, kv = get_positional_and_keyword(haystack, parsed)
  pp({ pos, kv })
end

test()
return optparser
