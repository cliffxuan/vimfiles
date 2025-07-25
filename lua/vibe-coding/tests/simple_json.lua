-- Simple JSON encoder for basic use cases

local M = {}

local function escape_string(str)
  return str:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
end

local function encode_value(value)
  local t = type(value)
  if t == 'string' then
    return '"' .. escape_string(value) .. '"'
  elseif t == 'number' then
    return tostring(value)
  elseif t == 'boolean' then
    return value and 'true' or 'false'
  elseif t == 'nil' then
    return 'null'
  elseif t == 'table' then
    if #value > 0 then
      -- Array
      local parts = {}
      for i, v in ipairs(value) do
        table.insert(parts, encode_value(v))
      end
      return '[' .. table.concat(parts, ', ') .. ']'
    else
      -- Object
      local parts = {}
      for k, v in pairs(value) do
        table.insert(parts, '"' .. escape_string(tostring(k)) .. '": ' .. encode_value(v))
      end
      return '{' .. table.concat(parts, ', ') .. '}'
    end
  else
    error('Cannot encode value of type ' .. t)
  end
end

function M.encode(value)
  return encode_value(value)
end

return M
