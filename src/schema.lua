local typedefs = require "kong.db.schema.typedefs"

local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local schema = {
  name = plugin_name,
  fields = {
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { response_header = typedefs.header_name {
              required = true,
              default = "x-"..plugin_name.."-cohort" } },
          { customer_separator_service_uri = { 
              type = "string",
              required = true } },
          { customer_separator_service_timeout_seconds = { 
              default = 60, 
              type = "number",
              gt = 0 } },
          { old_cohort_service_uri = { 
              type = "string",
              required = true } },
          { new_cohort_service_uri = { 
              type = "string",
              required = true } },
        },
        entity_checks = {
          { distinct = { "old_cohort_uri", "new_cohort_uri"} },   -- We specify that both uri cannot be the same
        },
      },
    },
  },
}

return schema
