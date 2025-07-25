-- VibeAPI: Handles communication with the OpenAI API
local Utils = require 'vibe-coding.utils'

local VibeAPI = {}

-- Helper function to build curl arguments
local function build_curl_args(json_file_path, headers_file_path, config)
  local args = {
    '-s',
    '-N',
    '-X',
    'POST',
    config.api_url .. '/chat/completions',
    '-H',
    'Content-Type: application/json',
    '-H',
    'Authorization: Bearer ' .. config.api_key,
    '-d',
    '@' .. json_file_path,
  }

  if headers_file_path then
    table.insert(args, 3, '-D')
    table.insert(args, 4, headers_file_path)
  end

  return args
end

-- Function to write debug curl script
function VibeAPI.write_debug_script(messages, config)
  local data = {
    model = config.model,
    messages = messages,
    stream = true,
  }

  local json_data, json_err = Utils.json_encode(data)
  if not json_data then
    vim.notify('[Vibe] Failed to encode JSON for debug script: ' .. json_err, vim.log.levels.ERROR)
    return
  end

  -- Create debug directory if it doesn't exist
  local debug_dir = vim.fn.stdpath 'data' .. '/vibe-debug'
  if vim.fn.isdirectory(debug_dir) == 0 then
    vim.fn.mkdir(debug_dir, 'p')
  end

  local timestamp = os.date '%Y%m%d_%H%M%S'
  local script_path = debug_dir .. '/vibe_api_call_' .. timestamp .. '.sh'
  local json_path = debug_dir .. '/vibe_request_' .. timestamp .. '.json'

  -- Write JSON data to separate file for readability
  local json_success, json_write_err = Utils.write_file(json_path, { json_data })
  if not json_success then
    vim.notify('[Vibe] Failed to write debug JSON: ' .. json_write_err, vim.log.levels.ERROR)
    return
  end

  -- Create the curl command script using shared function
  local endpoint = config.api_url .. '/chat/completions'
  local headers_file = debug_dir .. '/vibe_headers_' .. timestamp .. '.txt'
  local curl_args = build_curl_args(json_path, headers_file, config)

  -- Build curl command string for script
  local curl_command = 'curl'
  for _, arg in ipairs(curl_args) do
    if arg:match '^-[A-Za-z]$' then
      curl_command = curl_command .. ' ' .. arg
    elseif arg == config.api_key then
      curl_command = curl_command .. ' "$OPENAI_API_KEY"'
    else
      curl_command = curl_command .. ' "' .. arg .. '"'
    end
  end

  local script_content = {
    '#!/bin/bash',
    '# Vibe AI API Debug Script - Generated at ' .. os.date '%Y-%m-%d %H:%M:%S',
    '# Model: ' .. config.model,
    '# API URL: ' .. endpoint,
    '',
    'echo "Making API call to ' .. endpoint .. '"',
    'echo "Using model: ' .. config.model .. '"',
    'echo "Request payload saved to: ' .. json_path .. '"',
    'echo "Response headers will be saved to: ' .. headers_file .. '"',
    'echo ""',
    '',
    curl_command,
    '',
    'echo ""',
    'echo "Debug script completed"',
    'echo "Check ' .. headers_file .. ' for HTTP status and headers"',
  }

  local script_success, script_write_err = Utils.write_file(script_path, script_content)
  if not script_success then
    vim.notify('[Vibe] Failed to write debug script: ' .. script_write_err, vim.log.levels.ERROR)
    return
  end

  -- Make script executable
  vim.fn.system('chmod +x ' .. vim.fn.shellescape(script_path))

  vim.notify('[Vibe] Debug script written to: ' .. script_path, vim.log.levels.INFO)
  return script_path, json_path
end

-- Function to get streaming completion
function VibeAPI.get_completion(messages, callback, stream_callback, config)
  if not config.api_key or config.api_key == '' then
    vim.notify('[Vibe] OPENAI_API_KEY environment variable not set.', vim.log.levels.ERROR)
    callback(nil, 'API Key not set.')
    return
  end

  local data = {
    model = config.model,
    messages = messages,
    stream = true,
  }

  -- Safe JSON encoding
  local json_data, json_err = Utils.json_encode(data)
  if not json_data then
    callback(nil, json_err)
    return
  end

  -- Write debug script if debug mode is enabled
  if config.debug_mode then
    VibeAPI.write_debug_script(messages, config)
  end

  -- Create a temporary file for the JSON payload
  local temp_json_path = vim.fn.tempname()
  local temp_file_success, temp_file_err = Utils.write_file(temp_json_path, { json_data })
  if not temp_file_success then
    vim.notify('[Vibe] Failed to write temporary request file: ' .. temp_file_err, vim.log.levels.ERROR)
    callback(nil, 'Failed to create temp file for request.')
    return
  end

  local accumulated_content = ''
  local buffer = ''
  local temp_output_file = vim.fn.tempname()
  local plenary_job = require 'plenary.job'

  plenary_job
    :new({
      command = 'curl',
      args = build_curl_args(temp_json_path, temp_output_file, config),
      on_stdout = vim.schedule_wrap(function(_, data_chunk)
        if not data_chunk or data_chunk == '' then
          return
        end

        buffer = buffer .. data_chunk .. '\n'
        local lines = vim.split(buffer, '\n', { plain = true })
        buffer = lines[#lines]

        for i = 1, #lines - 1 do
          local line = lines[i]
          if line:match '^data: ' then
            local json_str = line:sub(7) -- Remove 'data: ' prefix
            if json_str == '[DONE]' then
              return
            end

            local chunk_data, _ = Utils.json_decode(json_str)
            if chunk_data and chunk_data.choices and #chunk_data.choices > 0 then
              local delta = chunk_data.choices[1].delta
              if delta and delta.content then
                accumulated_content = accumulated_content .. delta.content
                if stream_callback then
                  stream_callback(delta.content)
                end
              end
            elseif chunk_data and chunk_data.error then
              -- Handle API error responses
              local error_msg = chunk_data.error.message or 'API error occurred'
              if chunk_data.error.code == 'invalid_api_key' then
                vim.notify('[Vibe] Authentication failed - API key is invalid or expired', vim.log.levels.ERROR)
              else
                vim.notify('[Vibe] API Error: ' .. error_msg, vim.log.levels.ERROR)
              end
              callback(nil, error_msg)
              return
            end
          elseif line:match '^{.*"error".*}$' then
            -- Handle non-streaming error responses
            local error_data, _ = Utils.json_decode(line)
            if error_data and error_data.error then
              local error_msg = error_data.error.message or 'API error occurred'
              if error_data.error.code == 'invalid_api_key' then
                vim.notify('[Vibe] Authentication failed - API key is invalid or expired', vim.log.levels.ERROR)
              else
                vim.notify('[Vibe] API Error: ' .. error_msg, vim.log.levels.ERROR)
              end
              callback(nil, error_msg)
              return
            end
          end
        end
      end),
      on_exit = vim.schedule_wrap(function(job, return_val)
        -- Clean up the temporary files
        vim.fn.delete(temp_json_path)

        -- Check HTTP status from headers file
        local headers_content = {}
        if vim.fn.filereadable(temp_output_file) == 1 then
          headers_content = vim.fn.readfile(temp_output_file)
          vim.fn.delete(temp_output_file)
        end

        -- Parse HTTP status code from first line
        local http_status = ''
        if #headers_content > 0 then
          local status_line = headers_content[1]
          http_status = status_line:match 'HTTP/[%d%.]+%s+(%d+)'
        end

        if return_val == 0 then
          -- Check for authentication errors
          if http_status == '401' then
            vim.notify('[Vibe] Authentication failed - API key is invalid or expired', vim.log.levels.ERROR)
            callback(nil, 'Invalid or expired API key')
            return
          elseif http_status == '403' then
            vim.notify('[Vibe] Access forbidden - check API key permissions', vim.log.levels.ERROR)
            callback(nil, 'API key access forbidden')
            return
          elseif http_status and tonumber(http_status) >= 400 then
            vim.notify('[Vibe] API request failed with HTTP ' .. http_status, vim.log.levels.ERROR)
            callback(nil, 'HTTP error: ' .. http_status)
            return
          end

          vim.notify '[Vibe] Done calling API'
          callback(accumulated_content)
        else
          local stderr = job:stderr_result()
          local error_msg = stderr and table.concat(stderr, '\n') or 'HTTP request failed.'
          vim.notify('[Vibe] Error calling API: ' .. error_msg, vim.log.levels.ERROR)
          callback(nil, error_msg)
        end
      end),
    })
    :start()
end

return VibeAPI
