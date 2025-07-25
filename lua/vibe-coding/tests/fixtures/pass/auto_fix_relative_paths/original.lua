-- vibe-coding/utils.lua
local Utils = {}

function Utils.read_file_content(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    return nil, 'Could not open file: ' .. filepath
  end

  local content = file:read '*all'
  file:close()
  return content, nil
end

return Utils
