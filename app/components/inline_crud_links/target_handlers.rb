# frozen_string_literal: true

# Per-target-type handler methods named by `Components::InlineCRUDLinks::
# TARGET_HANDLERS` -- split out from the main class purely to keep it
# under the Metrics/ClassLength limit. Mixed into `InlineCRUDLinks`
# itself, not a standalone concept -- these methods read `@target`/
# `@observation`/`@user`, set by the including class's props.
module Components::InlineCRUDLinks::TargetHandlers
  private

  # ---- :tab handlers ----------------------------------------

  # No `@observation` only happens from the standalone
  # collection_numbers/herbarium_records index pages (the
  # observation-show sub-panel always passes one) -- `from_index:`
  # tells the Tab to route the post-edit redirect back to the index
  # instead of the record's show page.
  def tab_collection_number_edit
    ::Tab::CollectionNumber::Edit.new(
      collection_number: @target, observation: @observation,
      from_index: @observation.nil?
    )
  end

  def tab_herbarium_record_edit
    ::Tab::HerbariumRecord::Edit.new(
      herbarium_record: @target, observation: @observation,
      from_index: @observation.nil?
    )
  end

  # Sequence belongs_to one Observation -- `@target.observation` is
  # always the right object, so callers no longer need to pass
  # `observation:` for Sequence targets.
  def tab_sequence_edit
    ::Tab::Sequence::Edit.new(
      sequence: @target, observation: @target.observation
    )
  end

  def tab_external_link_edit
    ::Tab::ExternalLink::Edit.new(link: @target)
  end

  def tab_naming_edit
    ::Tab::Naming::Edit.new(naming: @target)
  end

  def tab_comment_edit
    ::Tab::Comment::Edit.new(comment: @target)
  end

  def tab_description_edit
    ::Tab::Description::Edit.new(description: @target)
  end

  def tab_publication_edit
    ::Tab::Publication::Edit.new(publication: @target)
  end

  def tab_project_alias_edit
    ::Tab::Project::AliasEdit.new(
      project_id: @target.project_id,
      name: :edit_object.t(type: :project_alias),
      id: @target.id
    )
  end

  # Plain page-navigation edit button -- VisualModel/VisualGroup have
  # no modal edit form, unlike every other target above.
  # `Button::Edit` already defaults `icon: :edit`.
  def crud_edit_button
    ::Components::Button.new(
      type: :edit, target: @target, variant: :strip,
      class: ::Components::InlineIconBlock.item_class
    )
  end

  # ---- :destroy_path handlers -------------------------------

  # Default -- pass the model and let `Button::Delete` build
  # `record_path(id)`.
  def path_target = @target

  # "Detach from obs" -- record-path with `observation_id:` query so
  # the controller detaches rather than destroys the record.
  # `CollectionNumber` / `HerbariumRecord` can be attached to
  # multiple obs. No `@observation` (the CollectionNumbers/
  # HerbariumRecords indexes, not an observation-show sub-panel) --
  # plain record destroy, same as `path_target`.
  def path_detach_from_obs
    return path_target unless @observation

    send(:"#{@target.type_tag}_path",
         @target.id, observation_id: @observation.id)
  end

  # Sequence destroy keeps a `back: permanent_observation_path(obs)` query so
  # the controller redirects to the obs after destroying.
  def path_sequence_with_back
    sequence_path(id: @target.id,
                  back: permanent_observation_path(@target.observation))
  end

  # Namings are nested under observations in routing; no top-level
  # `naming_path` helper exists.
  def path_observation_naming
    observation_naming_path(
      observation_id: @target.observation_id, id: @target.id
    )
  end

  # ProjectAlias is nested under its project in routing.
  def path_project_alias
    project_alias_path(project_id: @target.project_id, id: @target.id)
  end

  # ---- :destroy_name handlers -------------------------------

  # No `@observation` (the CollectionNumbers/HerbariumRecords
  # indexes) -- plain destroy, not a detach, so the label reads
  # "Destroy", matching `path_detach_from_obs`'s fallback.
  def name_remove
    return name_destroy_object unless @observation

    :remove.ti
  end

  def name_destroy_object = :destroy_object.t(type: @target.type_tag)

  # ---- :destroy_class handlers ------------------------------

  def class_remove_collection_number
    return "destroy_collection_number_link_#{@target.id}" unless @observation

    "remove_collection_number_link_#{@target.id}"
  end

  def class_remove_herbarium_record
    return "destroy_herbarium_record_link_#{@target.id}" unless @observation

    "remove_herbarium_record_link_#{@target.id}"
  end

  def class_destroy_sequence
    "destroy_sequence_link_#{@target.id}"
  end

  def class_destroy_external_link
    "destroy_external_link_link_#{@target.id}"
  end

  # The pre-Phlex `naming_destroy_button` set this class explicitly
  # so the namings integration tests could click it via
  # `find_button(class: "destroy_naming_link_<id>")`. Keep the
  # identifier hook.
  def class_destroy_naming
    "destroy_naming_link_#{@target.id}"
  end

  # ---- :destroy_confirm handlers ----------------------------

  # No `@observation` (the CollectionNumbers/HerbariumRecords
  # indexes) -- plain destroy, not a detach, so fall back to
  # `Button::Delete`'s generic confirm instead of the
  # remove-from-observation wording.
  def confirm_remove_object
    return nil unless @observation

    :remove_object_confirm.t(type: @target.type_tag, association: :observation)
  end

  # ---- :can_edit handlers -----------------------------------

  # CollectionNumber: edit gated by the OBS's edit permission,
  # rechecked per-record. No `@observation` (the CollectionNumbers/
  # HerbariumRecords indexes, not an observation-show sub-panel) --
  # falls back to the record's edit permission.
  def can_edit_via_observation?
    return @target.can_edit?(@user) || in_admin_mode? unless @observation

    @observation.can_edit?(@user) || in_admin_mode?
  end

  # HerbariumRecord / Sequence / ExternalLink: per-record edit
  # permission. Important for HRs and ELs: a user with edit
  # permission on the OBS may not own every record attached.
  def can_edit_via_target?
    @target.can_edit?(@user) || in_admin_mode?
  end

  # Owner-or-admin. Gating at the render side hides misleading
  # affordances rather than letting the controller reject the action
  # server-side after a user sees a link they can't use.
  def can_edit_via_owner?
    @target.user == @user || in_admin_mode?
  end

  # ProjectAlias: only project admins can edit/destroy aliases --
  # matches Projects::AliasesController's must_be_admin! gate.
  def can_edit_via_project_admin?
    @target.project.is_admin?(@user) || in_admin_mode?
  end

  # NameDescription writer permission -- `desc.writer?(user)` covers
  # per-user / per-group writer membership.
  def can_edit_via_writer?
    @target.writer?(@user) || in_admin_mode?
  end

  # VisualModel/VisualGroup: no permission restriction beyond being
  # logged in -- matches the pre-InlineCRUDLinks pages, which showed
  # these links to any signed-in user.
  def can_edit_unrestricted?
    true
  end

  # ---- :can_destroy handlers (override only when distinct) --

  # NameDescription destroy needs admin permission (stricter than
  # writer): only the description's admin group / record owner /
  # site-admin can delete.
  def can_destroy_via_admin?
    @target.is_admin?(@user) || in_admin_mode?
  end
end
