# frozen_string_literal: true

# "Add to a Project" link — stands in as the Projects panel's whole
# heading when the observation doesn't belong to any project yet.
# Caller must guard on `user.projects_member.any?` — same convention as
# `Tab::Observation::ManageProjects`.
class Tab::Observation::AddToProject < Tab::Base
  def initialize(observation:, q_param: nil)
    super()
    @observation = observation
    @q_param = q_param
  end

  def title
    :show_observation_add_to_project.l
  end

  def path
    with_q_param(edit_observation_projects_path(@observation.id), @q_param)
  end

  def html_options
    { icon: :add }
  end

  def model
    @observation
  end
end
