# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_image(key, args = {})
    declare_parameter(key, :image, args)
    str = get_param(key)
    return args[:default] unless str
    val = try_parsing_id(str, Image)
    fail BadParameterValue.new(str, :image) unless val
    check_edit_permission!(val, args)
    val
  end
end
