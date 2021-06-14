-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")

---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
---------------------------------------------------------------------------------------------


local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "1.0",
}


local json = require("cjson")
local url = require("socket.url")


-- do initialization here, any module level code runs in the 'init_by_lua_block',
-- before worker processes are forked. So anything you add here will run once,
-- but be available in all workers.


-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()

  -- your custom code here
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
  
  kong.log.inspect(plugin_conf)   
  
  local name = "[customer-separator]"
  local cohort, uri
  local ok, err
  
  local parsed_uri = parse_url(plugin_conf.customer_separator_service_uri)
  local scheme = parsed_uri.scheme
  local host = parsed_uri.host
  local port = tonumber(parsed_uri.port)

  local sock = ngx.socket.tcp()
  sock:settimeout(plugin_conf.customer_separator_service_timeout_seconds)
  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. " failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if scheme == HTTPS then
    local _, err = sock:sslhandshake(true, customer_separator_service_host, false)
    if err then
      ngx.log(ngx.ERR, name .. " failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  ok, err = sock:send(payload)
  if not ok then
    ngx.log(ngx.ERR, name .. " failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  local line, err = sock:receive("*l")

  if err then 
    ngx.log(ngx.ERR, name .. " failed to read response status from " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  local status_code = tonumber(string.match(line, "%s(%d%d%d)%s"))
  local headers = {}

  repeat
    line, err = sock:receive("*l")
    if err then
      ngx.log(ngx.ERR, name .. " failed to read header " .. host .. ":" .. tostring(port) .. ": ", err)
      return
    end

    local pair = ngx_re_match(line, "(.*):\\s*(.*)", "jo")

    if pair then
      headers[string.lower(pair[1])] = pair[2]
    end
  until ngx_re_find(line, "^\\s*$", "jo")

  local body, err = sock:receive(tonumber(headers['content-length']))
  if err then
    ngx.log(ngx.ERR, name .. " failed to read body " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if status_code > 299 then
    if err then 
      ngx.log(ngx.ERR, name .. " failed to read response from " .. host .. ":" .. tostring(port) .. ": ", err)
    end

    local response_body = JSON:decode(string.match(body, "%b{}"))
    --kong.log.debug("customer-separator response:"..response_body)
  end

-----------

  if not is_empty(cohort)
  then
    if cohort == "NEW"
    then
      uri = plugin_conf.new_cohort_service_uri
    else
      uri = plugin_conf.old_cohort_service_uri
    end
  
    kong.service.request.set_header(plugin_conf.response_header, cohort)
    
    ngx.var.upstream_uri = uri
    ngx.redirect(replace, 302)
    
    --kong.log.debug("recognized cohort:"..cohort)
    --kong.log.debug("recognized uri:"..uri)
  end
  
end --]]


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

local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

local function is_empty(str)
  return str == nil or str == ''
end

-- return our plugin object
return plugin
