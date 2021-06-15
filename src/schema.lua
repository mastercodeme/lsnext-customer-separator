local typedefs = require "kong.db.schema.typedefs"

local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local schema = {
  name = plugin_name,
  fields = {
    { consumer = typedefs.no_consumer },  
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { response_header = typedefs.header_name {
              required = true,
              default = "x-"..plugin_name.."-cohort" } },
          { customer_separator_service_scheme = { 
              required = true,
              type = "string",
              default = "http",
              one_of = {"http", "https"} } },
          { customer_separator_service_host = { 
              type = "string",
              required = true } },
          { customer_separator_service_path = { 
              type = "string",
              required = true } },
          { customer_separator_service_port = { 
              type = "number",
              default = 80,
              required = true,
              gt = 0 } },
          { customer_separator_service_timeout_seconds = { 
              default = 60, 
              type = "number",
              gt = 0 } },
          { new_cohort_service_uri = { 
              type = "string",
              required = true } },
        }
      },
    },
  },
}

return schema
