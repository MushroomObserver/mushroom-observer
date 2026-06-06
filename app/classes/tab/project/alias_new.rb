# frozen_string_literal: true

# "Add Alias" button rendered above the project's alias list. Sets
# `model` so the auto-derived selector class is model-aware; the
# html_options carry the Bootstrap button styling because this Tab
# is rendered as a button in its context (not a plain link).
class Tab::Project::AliasNew < Tab::Base
  def initialize(project_id:, target_id:, target_type:)
    super()
    @project_id = project_id
    @target_id = target_id
    @target_type = target_type
  end

  def title
    :ADD.t
  end

  def path
    new_project_alias_path(project_id: @project_id,
                           target_id: @target_id,
                           target_type: @target_type)
  end

  def html_options
    { class: "btn btn-default" }
  end

  def model
    ProjectAlias
  end
end
