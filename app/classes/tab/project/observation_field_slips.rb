# frozen_string_literal: true

# Member-facing observation sub-tab linking to the project's field
# slips index. Unlike `Tab::Project::AdminFieldSlips`, this tab's
# title carries no count and the Collection that composes it only
# includes it when the project already has a `field_slip_prefix` --
# without one, a member has nothing to create here, so the tab is
# hidden entirely (admins still reach it via AdminSubtabs to set one).
class Tab::Project::ObservationFieldSlips < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :field_slips.ti
  end

  def path
    field_slips_path(project: @project.id)
  end

  def alt_title
    "field_slips"
  end
end
