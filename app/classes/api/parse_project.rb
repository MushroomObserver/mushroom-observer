# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_project(key, args = {})
    declare_parameter(key, :project, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :project) if str.blank?
    val = try_parsing_id(str, Project)
    val ||= Project.find_by_title(str)
    fail ObjectNotFoundByString.new(str, Project) unless val
    check_if_admin!(val, args)
    check_if_member!(val, args)
    val
  end

  private

  def check_if_admin!(proj, args)
    fail MustBeAdmin, proj if args[:must_be_admin] &&
                              !@user.projects_admin.include?(proj)
  end

  def check_if_member!(proj, args)
    fail MustBeMember, proj if args[:must_be_member] &&
                               !@user.projects_member.include?(proj)
  end
end
