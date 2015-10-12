# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_user(key, args = {})
    declare_parameter(key, :user, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :user) if str.blank?
    val = try_parsing_id(str, User)
    val ||= User.where("login = ? OR name = ?", str, str).first
    fail ObjectNotFoundByString.new(str, User) unless val
    check_edit_permission!(val, args)
    val
  end
end
