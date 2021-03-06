local plugin_name = "customer-separator"
local package_name = plugin_name
local package_version = "0.1.1"
local rockspec_revision = "1"


package = package_name
version = package_version .. "-" .. rockspec_revision
supported_platforms = { "linux", "macosx" }


description = {
  summary = "Customer separator plugin made for Liga Stavok by Maksim Kuznetsov, 2021",
}

source = {
  url = "https://github.com/mastercodeme/lsnext-customer-separator",
  tag = "0.1.1"
}

dependencies = {
}


build = {
  type = "builtin",
  modules = {
    ["kong.plugins." .. plugin_name .. ".handler"] = "./src/handler.lua",
    ["kong.plugins." .. plugin_name .. ".schema"] = "./src/schema.lua",
    ["kong.plugins." .. plugin_name .. ".json"] = "./src/json.lua",
  }
}
