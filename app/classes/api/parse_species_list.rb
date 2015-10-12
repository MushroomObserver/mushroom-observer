# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_species_list(key, args = {})
    declare_parameter(key, :species_list, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :species_list) if str.blank?
    val = try_parsing_id(str, SpeciesList)
    val ||= SpeciesList.find_by_title(str)
    fail ObjectNotFoundByString.new(str, SpeciesList) unless val
    check_edit_permission!(val, args)
    val
  end
end
