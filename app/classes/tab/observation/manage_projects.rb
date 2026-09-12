# frozen_string_literal: true

# "Manage projects for this observation" link. Caller must guard on
# `user.projects_member.any?` — the icon is reused from
# `Tab::Observation::ManageLists`, since both are "manage membership"
# affordances and no dedicated projects glyph exists.
class Tab::Observation::ManageProjects < Tab::Base
  def initialize(observation:, q_param: nil)
    super()
    @observation = observation
    @q_param = q_param
  end

  def title
    :show_observation_manage_projects.l
  end

  def path
    with_q_param(edit_observation_projects_path(@observation.id), @q_param)
  end

  def html_options
    { icon: :manage_lists }
  end

  def model
    @observation
  end
end
