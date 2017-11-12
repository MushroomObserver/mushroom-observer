# API
class API
  def parse_external_site(key, args = {})
    declare_parameter(key, :external_site, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :external_site) if str.blank?
    val = try_parsing_id(str, ExternalSite) ||
          ExternalSite.find_by_name(str)
    raise ObjectNotFoundByString.new(str, ExternalSite) unless val
    val
  end
end
