# frozen_string_literal: true

# "Edit" link for a single project alias — appears in the alias
# row's action column. Uses `InternalLink::Model` so the rendered
# selector class is `edit_project_alias_link` plus a per-id flavour
# (`edit_project_alias_link_<id>`) for stable per-row test targeting.
class Tab::Project::AliasEdit < Tab::Base
  def initialize(project_id:, name:, id:)
    super()
    @project_id = project_id
    @name = name
    @id = id
  end

  def title
    @name
  end

  def path
    edit_project_alias_path(project_id: @project_id, id: @id)
  end

  def alt_title
    :EDIT.t
  end

  def model
    # Pass the actual alias instance when available so InternalLink::Model
    # appends the per-id selector flavour. The caller passed only id/name
    # historically; we synthesize a stand-in carrying just `id` so the
    # `_link_<id>` flavour is preserved.
    ProjectAlias.new(id: @id)
  end
end
