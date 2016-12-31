# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_external_site(key, args = {})
    declare_parameter(key, :external_site, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :external_site) if str.blank?
    val = try_parsing_id(str, ExternalSite)
    val ||= ExternalSite.find_by_name(str)
    fail ObjectNotFoundByString.new(str, ExternalSite) unless val
    val
  end
end
