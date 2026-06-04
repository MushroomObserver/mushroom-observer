# frozen_string_literal: true

# Admin sub-tab linking to the project's field slips index
# (/field_slips?project=ID), which hosts the "Create Field Slips for
# the Project" link. Gives admins a way to reach field-slip creation
# even when the project has no observations yet. See #4442.
class Tab::Project::AdminFieldSlips < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.field_slips.count} #{:FIELD_SLIPS.l}"
  end

  def path
    field_slips_path(project: @project.id)
  end

  def alt_title
    "field_slips"
  end
end
