# frozen_string_literal: true

# "Edit member status" action-nav link on the project member edit
# form — wording differs from the generic `edit_project_tab`.
class Tab::Project::ChangeMemberStatus < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :change_member_status_edit.t
  end

  def path
    edit_project_path(@project.id)
  end
end
