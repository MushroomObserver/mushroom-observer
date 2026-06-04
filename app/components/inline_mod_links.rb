# frozen_string_literal: true

# Renders the inline "[ edit | destroy ]" mod-controls group that
# appears all over the observation-show sub-panels
# (`_collection_numbers`, `_herbarium_records`, `_sequences`,
# `_external_links`, the descriptions alt-list). Polymorphic on
# the target's class so callers shrink to one line:
#
#   render(Components::InlineModLinks.new(
#            target: cn, observation: obs, user: user
#          ))
#
# Distinct from "title mod links" (the icon row that lives in a
# page-heading bar). This component is for the inline
# bracketed-with-pipe pattern that sits next to a record's title
# in a list.
#
# The component picks the right Tab PORO for the edit modal, the
# right destroy URL — `CollectionNumber` / `HerbariumRecord` get a
# "detach from this observation" target (record itself survives);
# `Sequence` / `ExternalLink` / `NameDescription` get a true DELETE
# — and the right permission check. Returns nothing when the user
# can't edit; pass `indent: false` to skip the leading `.ml-2`
# wrapper.
#
class Components::InlineModLinks < Components::Base
  prop :target, _Any
  prop :observation, _Nilable(::Observation), default: nil
  prop :user, _Nilable(::User), default: nil
  prop :indent, _Boolean, default: true
  # Extra inline links to render BEFORE the edit/destroy pair —
  # currently used by `Sequences` for the "[archive]" link when
  # the sequence has a deposit URL. Each item must be a renderable
  # (Phlex component instance or SafeBuffer).
  prop :extras, _Array(_Nilable(_Any)), default: -> { [] }

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

  def edit_component
    return nil unless can_edit?

    case @target
    when ::NameDescription
      content, path, opts = ::Tab::Description::Edit.new(
        description: @target
      ).to_a
      Components::IconLink.new(content, path, **opts)
    else
      tab = edit_tab
      return nil unless tab

      name, path, opts = tab.to_a
      Components::ModalLink.new(
        "#{@target.type_tag}_#{@target.id}", name, path, **opts
      )
    end
  end

  def edit_tab
    case @target
    when ::CollectionNumber
      ::Tab::CollectionNumber::Edit.new(
        collection_number: @target, observation: @observation
      )
    when ::HerbariumRecord
      ::Tab::HerbariumRecord::Edit.new(
        herbarium_record: @target, observation: @observation
      )
    when ::Sequence
      ::Tab::Sequence::Edit.new(
        sequence: @target, observation: @observation
      )
    when ::ExternalLink
      ::Tab::ExternalLink::Edit.new(link: @target)
    end
  end

  def destroy_component
    return nil unless can_destroy?

    Components::CrudButton::Delete.new(
      target: destroy_target,
      name: destroy_name,
      icon: :remove,
      btn: nil,
      class: destroy_class,
      confirm: destroy_confirm
    )
  end

  # For "detach from obs" records (`CollectionNumber` /
  # `HerbariumRecord`), point the DELETE at the record path
  # with `observation_id:` so the controller knows to detach
  # rather than destroy. For real-delete records, target the
  # model directly and let `CrudButton::Delete` build the path.
  def destroy_target
    case @target
    when ::CollectionNumber, ::HerbariumRecord
      send(:"#{@target.type_tag}_path",
           @target.id, observation_id: @observation.id)
    when ::Sequence
      sequence_path(id: @target.id, back: observation_path(@observation))
    else
      @target
    end
  end

  def destroy_name
    case @target
    when ::CollectionNumber, ::HerbariumRecord
      :REMOVE.l
    else
      :destroy_object.t(type: @target.type_tag)
    end
  end

  def destroy_class
    case @target
    when ::CollectionNumber
      "remove_collection_number_link_#{@target.id}"
    when ::HerbariumRecord
      "remove_herbarium_record_link_#{@target.id}"
    when ::Sequence
      "destroy_sequence_link_#{@target.id}"
    when ::ExternalLink
      "destroy_external_link_link_#{@target.id}"
    end
  end

  def destroy_confirm
    case @target
    when ::CollectionNumber
      :show_observation_remove_collection_number.l
    when ::HerbariumRecord
      :show_observation_remove_herbarium_record.l
    end
  end

  def can_edit?
    case @target
    when ::NameDescription
      @target.writer?(@user) || in_admin_mode?
    when ::CollectionNumber
      # CollectionNumber: edit gated by the OBS's edit permission
      # — the pre-Phlex `_collection_numbers.erb` precomputed
      # `can_edit = in_admin_mode? || obs.can_edit?(user)` once
      # for the whole list and didn't recheck per-record.
      @observation &&
        (@observation.can_edit?(@user) || in_admin_mode?)
    else
      # HerbariumRecord / Sequence / ExternalLink: per-record
      # edit permission (`record.can_edit?(user)`). Important
      # for HRs and EL: a user with edit permission on the OBS
      # may not own every record attached to it.
      @target.can_edit?(@user) || in_admin_mode?
    end
  end

  def can_destroy?
    case @target
    when ::NameDescription
      @target.is_admin?(@user) || in_admin_mode?
    else
      can_edit?
    end
  end
end
