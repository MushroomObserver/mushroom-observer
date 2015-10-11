# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_observation(key, args = {})
    declare_parameter(key, :observation, args)
    str = get_param(key)
    return args[:default] unless str
    val = try_parsing_id(str, Observation)
    fail BadParameterValue.new(str, :observation) unless val
    check_edit_permission!(val, args)
    val
  end
end
