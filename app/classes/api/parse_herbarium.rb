# API
class API
  def parse_herbarium(key, args = {})
    declare_parameter(key, :herbarium, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :herbarium) if str.blank?
    val = try_parsing_id(str, Herbarium) ||
          Herbarium.find_by_name(str) ||
          Herbarium.find_by_code(str)
    raise ObjectNotFoundByString.new(str, Herbarium) unless val
    check_edit_permission!(val, args)
    val
  end
end
