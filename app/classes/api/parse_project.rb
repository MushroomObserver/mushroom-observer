# API
class API
  def parse_project(key, args = {})
    declare_parameter(key, :project, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :project) if str.blank?
    val = try_parsing_id(str, Project) ||
          Project.find_by_title(str)
    raise ObjectNotFoundByString.new(str, Project) unless val
    check_if_admin!(val, args)
    check_if_member!(val, args)
    val
  end

  private

  def check_if_admin!(proj, args)
    return if !args[:must_be_admin] || @user.projects_admin.include?(proj)
    raise MustBeAdmin.new(proj)
  end

  def check_if_member!(proj, args)
    return if !args[:must_be_member] || @user.projects_member.include?(proj)
    raise MustBeMember.new(proj)
  end
end
