# frozen_string_literal: true

# "Add Alias" button rendered above the project's alias list.
# Sets `model` so the auto-derived selector class is model-aware.
# Callers own the btn styling via `Components::Button::ModalToggle`.
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
    {}
  end

  def model
    ProjectAlias
  end
end
