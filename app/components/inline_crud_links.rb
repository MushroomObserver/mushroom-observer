# frozen_string_literal: true

# Renders the inline edit/destroy or add link group that appears all
# over the observation-show sub-panels (`_collection_numbers`,
# `_herbarium_records`, `_sequences`, `_external_links`, the
# descriptions alt-list, the namings table, the comments-for-object
# list), plus the project aliases table. Keyed on presence/absence of
# `target:` -- both shapes are
# ultimately "one or two links derived from an object": `target:`
# present dispatches the edit/destroy pair (polymorphic on the
# target's class), `target:` absent dispatches the single add link
# (needs `tab:` + `modal_id:` instead).
#
#   InlineCRUDLinks(target: cn, observation: obs, user: user)
#   InlineCRUDLinks(tab: ::Tab::CollectionNumber::New.new(observation: obs),
#                  modal_id: "collection_number")
#
# Layout glue lives in `Components::InlineLinkBlock` -- this component
# only builds the item list and hands it off. Every item it builds
# gets `Components::InlineLinkBlock.item_class(...)` merged in (e.g.
# with a per-record destroy-button selector class) so `.inline-icon-link`
# lands on the item's own element -- `InlineLinkBlock` can't do that
# itself, see its own doc comment.
#
# Each supported target's edit/destroy/permission behavior is
# centralized in `TARGET_HANDLERS` below -- one method-symbol entry
# per branch (edit / destroy / permission). Adding a new target type
# means adding one row to that hash plus the private methods it
# names. `destroy_path` defaults to `:path_target` and `destroy_name`
# to `:name_destroy_object` when absent from a handler -- only
# genuinely non-standard targets need to override them.
#
# Why a Tab-PORO dispatch table here but not on the page-title-bar
# edit/delete icons (`Header::EditDeleteIcons`): that component is
# fully generic across every model (always the model's own standard
# edit page, gated by its own `can_edit?`/`destroyable?`), with no
# per-model behavior to carry. Here the behavior varies per target --
# modal edit vs. plain link, detach-not-destroy paths, different
# permission predicates -- which is what a Tab PORO carries.
class Components::InlineCRUDLinks < Components::Base
  include Components::InlineCRUDLinks::TargetHandlers

  # Target is polymorphic; the supported classes are the keys of
  # `TARGET_HANDLERS` below. `target:` present/absent is what
  # selects edit/destroy mode vs. add mode.
  prop :target, _Nilable(_Union(::CollectionNumber, ::HerbariumRecord,
                                ::Sequence, ::ExternalLink,
                                ::Naming, ::Comment, ::Description,
                                ::Publication, ::ProjectAlias)),
       default: nil
  # CollectionNumber / HerbariumRecord: required -- permission and/or
  # the detach path need the observation. Every other target derives
  # what it needs from `target:` itself.
  prop :observation, _Nilable(::Observation), default: nil
  prop :user, _Nilable(::User), default: nil
  # Extra inline links to render BEFORE the edit/destroy pair --
  # currently used by `Sequences` for the "[archive]" link when the
  # sequence has a deposit URL. Each item must be a renderable
  # (Phlex component instance or SafeBuffer string). `target:` mode
  # only.
  prop :extras, _Array(_Nilable(_Union(Phlex::SGML, String))),
       default: -> { [] }
  # Add-link mode (`target:` absent) needs these instead.
  prop :tab, _Nilable(::Tab::Base), default: nil
  prop :modal_id, _Nilable(String), default: nil

  # Per-target dispatch table. Keys: model class. Values: hash of
  # method-symbols this component calls to derive the per-target
  # behavior. See the corresponding private methods below.
  #
  # The dispatch table approach keeps each target's full handler set
  # visible in one place, instead of scattered across parallel
  # `case @target` statements. Adding a new target type: add one row
  # here + the private methods it names, done.
  TARGET_HANDLERS = {
    ::CollectionNumber => {
      edit: :modal_link_edit,
      tab: :tab_collection_number_edit,
      destroy_path: :path_detach_from_obs,
      destroy_name: :name_remove,
      destroy_class: :class_remove_collection_number,
      destroy_confirm: :confirm_remove_object,
      can_edit: :can_edit_via_observation?
    },
    ::HerbariumRecord => {
      edit: :modal_link_edit,
      tab: :tab_herbarium_record_edit,
      destroy_path: :path_detach_from_obs,
      destroy_name: :name_remove,
      destroy_class: :class_remove_herbarium_record,
      destroy_confirm: :confirm_remove_object,
      can_edit: :can_edit_via_target?
    },
    ::Sequence => {
      edit: :modal_link_edit,
      tab: :tab_sequence_edit,
      destroy_path: :path_sequence_with_back,
      destroy_class: :class_destroy_sequence,
      can_edit: :can_edit_via_target?
    },
    ::ExternalLink => {
      edit: :modal_link_edit,
      tab: :tab_external_link_edit,
      destroy_class: :class_destroy_external_link,
      can_edit: :can_edit_via_target?
    },
    ::Naming => {
      edit: :modal_link_edit,
      tab: :tab_naming_edit,
      modal_id: :modal_id_naming,
      destroy_path: :path_observation_naming,
      destroy_class: :class_destroy_naming,
      can_edit: :can_edit_via_owner?
    },
    ::Comment => {
      edit: :modal_link_edit,
      tab: :tab_comment_edit,
      can_edit: :can_edit_via_owner?
    },
    ::ProjectAlias => {
      edit: :modal_link_edit,
      tab: :tab_project_alias_edit,
      destroy_path: :path_project_alias,
      can_edit: :can_edit_via_member?
    },
    # Both `NameDescription` and `LocationDescription` inherit from
    # `Description`. Keyed on the parent so the ancestor walk in
    # `#handler` resolves either subclass.
    ::Description => {
      edit: :icon_link_edit,
      tab: :tab_description_edit,
      can_edit: :can_edit_via_writer?,
      can_destroy: :can_destroy_via_admin?
    },
    ::Publication => {
      edit: :icon_link_edit,
      tab: :tab_publication_edit,
      can_edit: :can_edit_via_target?
    }
  }.freeze

  def view_template
    InlineLinkBlock(items: items)
  end

  private

  def items
    @target ? crud_items : add_items
  end

  def crud_items
    [*@extras.compact, edit_component, destroy_component].compact
  end

  def add_items
    [add_component]
  end

  # Icon-only -- `name:` (the tab's own descriptive title, e.g. "Add
  # fungarium record") drives the tooltip + sr-only text but isn't
  # shown visibly (no `show_text:`), matching the pre-consolidation
  # `Components::Link::InlineAdd` behavior.
  def add_component
    Components::Link.new(
      type: :modal,
      name: @tab.title,
      target: @tab.path,
      modal_id: @modal_id,
      icon: :add,
      **tab_html_options(@tab)
    )
  end

  # Merges `.inline-icon-link` into a Tab's own `html_options[:class]`
  # (e.g. a per-record selector class) rather than overwriting it.
  def tab_html_options(tab)
    tab.html_options.merge(
      class: Components::InlineLinkBlock.item_class(tab.html_options[:class])
    )
  end

  # Walk the target's ancestor chain looking for a matching handler.
  # Lets `LocationDescription` and `NameDescription` share the
  # `::Description` parent entry, and gives future subclasses of any
  # supported model the right behavior for free.
  def handler
    @handler ||= @target.class.ancestors.lazy.
                 map { |k| TARGET_HANDLERS[k] }.find(&:itself) ||
                 raise(KeyError.new("No InlineCRUDLinks handler for " \
                                 "#{@target.class}"))
  end

  def edit_component
    return nil unless can_edit?

    send(handler[:edit])
  end

  def destroy_component
    return nil unless can_destroy?

    Components::Button.new(type: :delete, **destroy_args)
  end

  def destroy_args
    {
      target: send(handler[:destroy_path] || :path_target),
      name: send(handler[:destroy_name] || :name_destroy_object),
      icon: :remove,
      variant: :strip,
      class: destroy_class,
      confirm: handler[:destroy_confirm] && send(handler[:destroy_confirm])
    }
  end

  def destroy_class
    Components::InlineLinkBlock.item_class(
      handler[:destroy_class] && send(handler[:destroy_class])
    )
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

    Components::Button.new(
      type: :modal,
      name: tab.title,
      target: tab.path,
      modal_id: modal_id,
      variant: :strip,
      **tab_html_options(tab)
    )
  end

  def icon_link_edit
    tab = send(handler[:tab])
    Components::Link::Get.new(
      tab: tab,
      class: Components::InlineLinkBlock.item_class(tab.html_options[:class])
    )
  end

  # Modal element id. Default `"<type_tag>_<id>"` matches the
  # `dom_id`-style convention; `Naming` uses a custom shape that
  # includes the obs id because the namings table can render several
  # modals for the same observation simultaneously.
  def modal_id
    handler[:modal_id] ? send(handler[:modal_id]) : default_modal_id
  end

  def default_modal_id
    "#{@target.type_tag}_#{@target.id}"
  end

  def modal_id_naming
    "obs_#{@target.observation_id}_naming_#{@target.id}"
  end
end
