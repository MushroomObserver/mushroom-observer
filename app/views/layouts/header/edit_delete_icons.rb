# frozen_string_literal: true

# Page-title-bar edit/delete icons. Renders edit + delete buttons
# gated by what the viewer can do to the object, via the same
# `Components::InlineLinkBlock` spacing/styling every other inline
# edit/destroy icon pair in the app uses (see `Components::
# InlineCRUDLinks`) -- unlike that component's own `TARGET_HANDLERS`
# dispatch, this stays generic across every model via plain
# `AbstractModel#can_edit?`/`#destroyable?`, so it needs no per-model
# handler. The wrapping `div` always renders -- empty when the viewer
# has no permissions -- so the parent flex layout in `Views::Layouts::
# Header::PageTitle` is consistent regardless of permission state.
#
# Rendered into `content_for(:edit_icons)` by
# `Views::FullPageBase::Icons#add_edit_icons`.
#
# `Location` has a stricter destroy gate (model `destroyable?` + the
# viewer owns the record or is in admin mode); `Observation` hides the
# icon entirely for a read-only reflection (#5293) and shows a
# read-only status icon beside edit/delete instead; other models
# follow the edit-permission shape.
module Views::Layouts
  class Header::EditDeleteIcons < Views::Base
    prop :object, ::AbstractModel
    prop :user, _Nilable(::User), default: nil

    def view_template
      div(class: "h4 my-0 d-flex align-items-center object_edit") do
        render_reflection_icon if reflection?
        InlineLinkBlock(items: [edit_item, delete_item].compact)
      end
    end

    private

    def reflection?
      @object.is_a?(::Observation) && @object.reflection?
    end

    def render_reflection_icon
      Icon(type: :read_only, title: :show_observation_reflection_read_only.l,
           wrap_class: "mr-2")
    end

    # A read-only reflection keeps its edit icon: Edit opens a linked
    # companion observation for the changes.
    def edit_item
      return nil unless can_edit_object?

      ::Components::Button::Edit.new(
        target: @object, variant: :strip,
        class: ::Components::InlineLinkBlock.item_class
      )
    end

    def delete_item
      return nil unless can_destroy_object?

      ::Components::Button::Delete.new(
        target: @object, variant: :strip,
        class: ::Components::InlineLinkBlock.item_class
      )
    end

    def can_edit_object?
      in_admin_mode? || @object.can_edit?(@user)
    end

    def can_destroy_object?
      return can_destroy_location? if @object.is_a?(::Location)
      return can_destroy_observation? if @object.is_a?(::Observation)

      can_edit_object?
    end

    def can_destroy_location?
      return false unless @object.destroyable?

      in_admin_mode? || @object.user == @user
    end

    # A read-only reflection can't be destroyed -- ObservationsController::
    # Destroy blocks the action itself; this hides the icon that would
    # otherwise offer it.
    def can_destroy_observation?
      return false if @object.reflection?

      can_edit_object?
    end
  end
end
