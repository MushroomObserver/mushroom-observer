# frozen_string_literal: true

# Renders the inline "[edit|destroy]" mod-controls group that
# appears all over the observation-show sub-panels
# (`_collection_numbers`, `_herbarium_records`, `_sequences`,
# `_external_links`, the descriptions alt-list, the namings
# table, the comments-for-object list). Polymorphic on the
# target's class so callers shrink to one line:
#
#   render(Components::Link::InlineMod.new(
#            target: cn, observation: obs, user: user
#          ))
#
# Distinct from "title mod links" (the icon row that lives in a
# page-heading bar). This component is for the inline
# bracketed-with-pipe pattern that sits next to a record's title
# in a list.
#
# Each supported target's behavior is centralized in
# `TARGET_HANDLERS` below — one method-symbol entry per branch
# (edit / destroy / permission). Adding a new target type means
# adding one row to that hash plus the four private methods it
# names. Use `indent: false` to skip the leading `.ml-2`
# wrapper.
#
class Components::Link::InlineMod < Components::Base
  # Target is polymorphic; the supported classes are exactly the
  # keys of `TARGET_HANDLERS` below.
  prop :target, _Union(::CollectionNumber, ::HerbariumRecord,
                       ::Sequence, ::ExternalLink,
                       ::Naming, ::Comment, ::Description)
  prop :observation, _Nilable(::Observation), default: nil
  prop :user, _Nilable(::User), default: nil
  prop :indent, _Boolean, default: true
  # Extra inline links to render BEFORE the edit/destroy pair —
  # currently used by `Sequences` for the "[archive]" link when
  # the sequence has a deposit URL. Each item must be a renderable
  # (Phlex component instance or SafeBuffer string).
  prop :extras, _Array(_Nilable(_Union(Phlex::SGML, String))),
       default: -> { [] }

  # Per-target dispatch table. Keys: model class. Values: hash
  # of method-symbols this component calls to derive the
  # per-target behavior. See the corresponding private methods
  # below.
  #
  # The dispatch table approach keeps each target's full handler
  # set visible in one place, instead of scattered across 6
  # parallel `case @target` statements. Adding a new target type:
  # add one row here + four (or fewer) private methods, done.
  TARGET_HANDLERS = {
    ::CollectionNumber => {
      edit: :modal_link_edit,
      tab: :tab_collection_number_edit,
      destroy_path: :path_detach_from_obs,
      destroy_name: :name_remove,
      destroy_class: :class_remove_collection_number,
      destroy_confirm: :confirm_remove_collection_number,
      can_edit: :can_edit_via_observation?
    },
    ::HerbariumRecord => {
      edit: :modal_link_edit,
      tab: :tab_herbarium_record_edit,
      destroy_path: :path_detach_from_obs,
      destroy_name: :name_remove,
      destroy_class: :class_remove_herbarium_record,
      destroy_confirm: :confirm_remove_herbarium_record,
      can_edit: :can_edit_via_target?
    },
    ::Sequence => {
      edit: :modal_link_edit,
      tab: :tab_sequence_edit,
      destroy_path: :path_sequence_with_back,
      destroy_name: :name_destroy_object,
      destroy_class: :class_destroy_sequence,
      can_edit: :can_edit_via_target?
    },
    ::ExternalLink => {
      edit: :modal_link_edit,
      tab: :tab_external_link_edit,
      destroy_path: :path_target,
      destroy_name: :name_destroy_object,
      destroy_class: :class_destroy_external_link,
      can_edit: :can_edit_via_target?
    },
    ::Naming => {
      edit: :modal_link_edit,
      tab: :tab_naming_edit,
      modal_id: :modal_id_naming,
      destroy_path: :path_observation_naming,
      destroy_name: :name_destroy_object,
      destroy_class: :class_destroy_naming,
      can_edit: :can_edit_via_owner?
    },
    ::Comment => {
      edit: :modal_link_edit,
      tab: :tab_comment_edit,
      destroy_path: :path_target,
      destroy_name: :name_destroy_object,
      can_edit: :can_edit_via_owner?
    },
    # Both `NameDescription` and `LocationDescription` inherit
    # from `Description`. Keyed on the parent so the ancestor
    # walk in `#handler` resolves either subclass.
    ::Description => {
      edit: :icon_link_edit,
      tab: :tab_description_edit,
      destroy_path: :path_target,
      destroy_name: :name_destroy_object,
      can_edit: :can_edit_via_writer?,
      can_destroy: :can_destroy_via_admin?
    }
  }.freeze

  def view_template
    items = [*@extras.compact, edit_component, destroy_component].compact
    return if items.empty?

    if @indent
      span(class: "ml-2") { render_items(items) }
    else
      render_items(items)
    end
  end

  private

  # Brackets and pipe-divider sit flush against the buttons —
  # the buttons themselves already carry `px-2` horizontal
  # padding from `link-icon px-2`, so adding `[ ` / ` | ` / ` ]`
  # spaces visually double-pads the group. Match the rendered
  # spacing to the button padding.
  def render_items(items)
    plain("[")
    items.each_with_index do |item, idx|
      plain("|") if idx.positive?
      render_item(item)
    end
    plain("]")
  end

  def render_item(item)
    if item.is_a?(Phlex::SGML)
      render(item)
    else
      trusted_html(item.to_s)
    end
  end

  # Walk the target's ancestor chain looking for a matching
  # handler. Lets `LocationDescription` and `NameDescription`
  # share the `::Description` parent entry, and gives future
  # subclasses of any supported model the right behavior for free.
  def handler
    @handler ||= @target.class.ancestors.lazy.
                 map { |k| TARGET_HANDLERS[k] }.find(&:itself) ||
                 raise(KeyError.new("No InlineModLinks handler for " \
                                 "#{@target.class}"))
  end

  def edit_component
    return nil unless can_edit?

    send(handler[:edit])
  end

  def destroy_component
    return nil unless can_destroy?

    Components::CRUDButton::Delete.new(**destroy_args)
  end

  def destroy_args
    {
      target: send(handler[:destroy_path]),
      name: send(handler[:destroy_name]),
      icon: :remove,
      # Match `Components::Link::Icon`'s `px-2` icon padding so the
      # destroy icon doesn't hug the surrounding `|` divider while
      # the edit `IconLink` next to it has breathing room.
      icon_class: "px-2",
      btn: nil,
      class: handler[:destroy_class] && send(handler[:destroy_class]),
      confirm: handler[:destroy_confirm] && send(handler[:destroy_confirm])
    }
  end

  def can_edit?
    send(handler[:can_edit])
  end

  def can_destroy?
    if handler[:can_destroy]
      send(handler[:can_destroy])
    else
      can_edit?
    end
  end

  # ---- :edit handlers ---------------------------------------

  def modal_link_edit
    tab = send(handler[:tab])
    return nil unless tab

    Components::Link::Modal.new(modal_id, tab: tab)
  end

  def icon_link_edit
    Components::Link::Icon.new(tab: send(handler[:tab]))
  end

  # Modal element id. Default `"<type_tag>_<id>"` matches the
  # `dom_id`-style convention; `Naming` uses a custom shape that
  # includes the obs id because the namings table can render
  # several modals for the same observation simultaneously.
  def modal_id
    handler[:modal_id] ? send(handler[:modal_id]) : default_modal_id
  end

  def default_modal_id
    "#{@target.type_tag}_#{@target.id}"
  end

  def modal_id_naming
    "obs_#{@target.observation_id}_naming_#{@target.id}"
  end

  # ---- :tab handlers ----------------------------------------

  def tab_collection_number_edit
    ::Tab::CollectionNumber::Edit.new(
      collection_number: @target, observation: @observation
    )
  end

  def tab_herbarium_record_edit
    ::Tab::HerbariumRecord::Edit.new(
      herbarium_record: @target, observation: @observation
    )
  end

  def tab_sequence_edit
    ::Tab::Sequence::Edit.new(sequence: @target, observation: @observation)
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

  # ---- :destroy_path handlers -------------------------------

  # Default — pass the model and let `CRUDButton::Delete` build
  # `record_path(id)`.
  def path_target = @target

  # "Detach from obs" — record-path with `observation_id:` query
  # so the controller detaches rather than destroys the record.
  # `CollectionNumber` / `HerbariumRecord` can be attached to
  # multiple obs.
  def path_detach_from_obs
    send(:"#{@target.type_tag}_path",
         @target.id, observation_id: @observation.id)
  end

  # Sequence destroy keeps a `back: observation_path(obs)` query
  # so the controller redirects to the obs after destroying.
  def path_sequence_with_back
    sequence_path(id: @target.id, back: observation_path(@observation))
  end

  # Namings are nested under observations in routing; no
  # top-level `naming_path` helper exists.
  def path_observation_naming
    observation_naming_path(
      observation_id: @target.observation_id, id: @target.id
    )
  end

  # ---- :destroy_name handlers -------------------------------

  def name_remove = :REMOVE.l
  def name_destroy_object = :destroy_object.t(type: @target.type_tag)

  # ---- :destroy_class handlers ------------------------------

  def class_remove_collection_number
    "remove_collection_number_link_#{@target.id}"
  end

  def class_remove_herbarium_record
    "remove_herbarium_record_link_#{@target.id}"
  end

  def class_destroy_sequence
    "destroy_sequence_link_#{@target.id}"
  end

  def class_destroy_external_link
    "destroy_external_link_link_#{@target.id}"
  end

  # The pre-Phlex `naming_destroy_button` set this class
  # explicitly so the namings integration tests could click it
  # via `find_button(class: "destroy_naming_link_<id>")`. Keep
  # the identifier hook.
  def class_destroy_naming
    "destroy_naming_link_#{@target.id}"
  end

  # ---- :destroy_confirm handlers ----------------------------

  def confirm_remove_collection_number
    :show_observation_remove_collection_number.l
  end

  def confirm_remove_herbarium_record
    :show_observation_remove_herbarium_record.l
  end

  # ---- :can_edit handlers -----------------------------------

  # CollectionNumber: edit gated by the OBS's edit permission —
  # the pre-Phlex `_collection_numbers.erb` precomputed
  # `can_edit = in_admin_mode? || obs.can_edit?(user)` once for
  # the whole list and didn't recheck per-record.
  def can_edit_via_observation?
    @observation &&
      (@observation.can_edit?(@user) || in_admin_mode?)
  end

  # HerbariumRecord / Sequence / ExternalLink: per-record edit
  # permission. Important for HRs and ELs: a user with edit
  # permission on the OBS may not own every record attached.
  def can_edit_via_target?
    @target.can_edit?(@user) || in_admin_mode?
  end

  # Owner-or-admin. Matches the `permission?` predicate that
  # gates the helper-side `[ edit | destroy ]` rendering in
  # `namings_helper.rb#naming_name_html`. Comments fix a
  # pre-existing pre-Phlex divergence: `_comment.erb` always
  # rendered the mod links regardless of ownership; the
  # controller would reject the action server-side. Gating at
  # the render side hides misleading affordances.
  def can_edit_via_owner?
    @target.user == @user || in_admin_mode?
  end

  # NameDescription writer permission — `desc.writer?(user)`
  # covers per-user / per-group writer membership.
  def can_edit_via_writer?
    @target.writer?(@user) || in_admin_mode?
  end

  # ---- :can_destroy handlers (override only when distinct) --

  # NameDescription destroy needs admin permission (stricter
  # than writer): only the description's admin group / record
  # owner / site-admin can delete.
  def can_destroy_via_admin?
    @target.is_admin?(@user) || in_admin_mode?
  end
end
