local plugin = {
  PRIORITY = 900, 
  VERSION = "0.1.1",
}

local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local JSON = require("kong.plugins." .. plugin_name .. ".json")
local url = require("socket.url")


local HTTP = "http"
local HTTPS = "https"

local COHORT_NEW = "NEW"
local COHORT_OLD = "OLD"


local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local read_body = ngx.req.read_body
local get_body = ngx.req.get_body_data
local get_method = ngx.req.get_method
local ngx_re_match = ngx.re.match
local ngx_re_find = ngx.re.find


local function is_empty(str)
  return str == nil or str == ''
end

local function make_request(host, path)
  local headers = get_headers()
  local uri_args = get_uri_args()
  local next = next
  
  read_body()
  local body_data = get_body()

  headers["origin-uri"] = ngx.var.request_uri
  headers["origin-method"] = ngx.var.request_method

  local raw_json_headers = JSON:encode(headers)
  local raw_json_body_data = JSON:encode(body_data)

  local raw_json_uri_args
  if next(uri_args) then 
    raw_json_uri_args = JSON:encode(uri_args) 
  else
    raw_json_uri_args = "{}"
  end

  local payload_body = [[{"headers":]] .. raw_json_headers .. [[,"query_params":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[}]]
  local payload_headers = string.format("POST %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: application/json\r\nContent-Length: %s\r\n",
    path, host, #payload_body)
  
  return string.format("%s\r\n%s", payload_headers, payload_body)
end

function plugin:init_worker()

  kong.log.debug("plugin 'customer-separator' successfully loaded")

end --]]


--[[ runs in the 'ssl_certificate_by_lua_block'
-- IMPORTANT: during the `certificate` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the plugin is
-- configured as a global plugin!
function plugin:certificate(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'certificate' handler")

end --]]


--[[ runs in the 'rewrite_by_lua_block'
-- IMPORTANT: during the `rewrite` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the plugin is
-- configured as a global plugin!
function plugin:rewrite(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'rewrite' handler")

end --]]


-- runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
  
  -- DEBUG
  --kong.log.inspect(plugin_conf)   
  
  local name = "[customer-separator]"
  local ok, err
  
  local scheme = plugin_conf.customer_separator_service_scheme
  local host = plugin_conf.customer_separator_service_host
  local path = plugin_conf.customer_separator_service_path
  local port = tonumber(plugin_conf.customer_separator_service_port)

  local sock = ngx.socket.tcp()
  sock:settimeout(plugin_conf.customer_separator_service_timeout_seconds * 1000)
  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. " failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return kong.response.exit(500, err)
  end

  if scheme == HTTPS then
    local _, err = sock:sslhandshake(true, customer_separator_service_host, false)
    if err then
      ngx.log(ngx.ERR, name .. " failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
      return kong.response.exit(500, err)
    end
  end

  local request = make_request(host, path)
  -- DEBUG
  --kong.log.inspect(request)   
  ok, err = sock:send(request)
  if not ok then
    ngx.log(ngx.ERR, name .. " failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
    return kong.response.exit(500, err)
  end

  local line, err = sock:receive("*l")

  if err then 
    ngx.log(ngx.ERR, name .. " failed to read response status from " .. host .. ":" .. tostring(port) .. ": ", err)
    return kong.response.exit(500, err)
  end

  local status_code = tonumber(string.match(line, "%s(%d%d%d)%s"))
  local headers = {}

  repeat
    line, err = sock:receive("*l")
    if err then
      ngx.log(ngx.ERR, name .. " failed to read header " .. host .. ":" .. tostring(port) .. ": ", err)
      return kong.response.exit(500, err)
    end

    local pair = ngx_re_match(line, "(.*):\\s*(.*)", "jo")

    if pair then
      headers[string.lower(pair[1])] = pair[2]
    end
  until ngx_re_find(line, "^\\s*$", "jo")

  local body, err = sock:receive(tonumber(headers['content-length']))
  if err then
    ngx.log(ngx.ERR, name .. " failed to read body " .. host .. ":" .. tostring(port) .. ": ", err)
    return kong.response.exit(500, err)
  end

  -- DEBUG
  --kong.log.inspect(status_code)
  --kong.log.inspect(body)
  if status_code > 299 then
    if err then 
      ngx.log(ngx.ERR, name .. " failed to read response from " .. host .. ":" .. tostring(port) .. ": ", err)
      return kong.response.exit(500, err)
    end
  else
    if not is_empty(body)
    then
      kong.service.request.set_header(plugin_conf.response_header, body)
      
      if (body == COHORT_NEW)
      then
        kong.service.request.set_path(plugin_conf.alternate_service_path)
        kong.service.request.set_scheme(plugin_conf.alternate_service_scheme)
        kong.service.set_target(plugin_conf.alternate_service_host, plugin_conf.alternate_service_port)
      end
    end
  end

end


--[[ runs in the 'header_filter_by_lua_block'
function plugin:header_filter(plugin_conf)

  -- your custom code here, for example;
  -- kong.response.set_header(plugin_conf.response_header, "this is on the response")

end --]]


--[[ runs in the 'body_filter_by_lua_block'
function plugin:body_filter(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'body_filter' handler")

end --]]


--[[ runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'log' handler")

end --]]


return plugin
