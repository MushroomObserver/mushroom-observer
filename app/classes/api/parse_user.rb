# API
class API
  def parse_user(key, args = {})
    declare_parameter(key, :user, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :user) if str.blank?
    val = try_parsing_id(str, User)
    val ||= User.where("login = ? OR name = ?", str, str).first
    raise ObjectNotFoundByString.new(str, User) unless val
    check_edit_permission!(val, args)
    val
  end
end
