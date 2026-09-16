# frozen_string_literal: true

# Joining a project by using one of its field slips.
#
# A slip's code prefix is an invitation: scanning a slip for an
# open-membership project enrolls you in it, at the "editing" trust
# every other enrollment path grants.
#
# Shared by the field slip form and the observation form so the rule has
# one definition; before #4932 only the field slip form did this, and
# routing a scan to the observation form would otherwise have dropped it.
module FieldSlipProjectJoinable
  extend ActiveSupport::Concern

  private

  # No-op when the project is nil, already joined, or not open to
  # self-enrollment.
  def join_field_slip_project(project)
    return unless project&.can_join?(@user)

    project.user_group.users << @user
    flash_notice(:field_slip_welcome.t(title: project.title))
    grant_field_slip_project_membership(project)
  end

  def grant_field_slip_project_membership(project)
    return if ProjectMember.find_by(project: project, user: @user)

    ProjectMember.create(project: project, user: @user,
                         trust_level: "editing")
    flash_notice(:add_members_with_editing.l)
  end
end
