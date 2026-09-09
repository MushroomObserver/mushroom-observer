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
# viewer owns the record or is in admin mode); other models follow
# the edit-permission shape.
module Views::Layouts
  class Header::EditDeleteIcons < Views::Base
    prop :object, ::AbstractModel
    prop :user, _Nilable(::User), default: nil
    # When set, the edit icon toggles this modal (by DOM id) instead of
    # navigating -- used for a non-primary occurrence member, whose edit
    # opens the choice modal (#5317). The edit route stays as the href,
    # so it degrades to a plain edit link without JS.
    prop :edit_modal_target, _Nilable(String), default: nil

    def view_template
      div(class: "h4 my-0 d-flex align-items-center object_edit") do
        InlineLinkBlock(items: [edit_item, delete_item].compact)
      end
    end

    private

    # A read-only reflection keeps its edit icon: Edit opens a linked
    # companion observation for the changes.
    def edit_item
      return nil unless can_edit_object?
      return edit_modal_toggle if @edit_modal_target

      ::Components::Button::Edit.new(
        target: @object, variant: :strip,
        class: ::Components::InlineLinkBlock.item_class
      )
    end

    # A plain <button> (no href) that opens the static choice modal via
    # Bootstrap data-toggle. Deliberately not a link: an edit href here
    # was navigable/prefetchable, so Turbo Drive would visit the edit
    # page in the background and swap it in under the open modal (#5317).
    def edit_modal_toggle
      ::Components::Button.new(
        icon: :edit, variant: :strip,
        icon_title: :edit_object.t(type: @object.type_tag),
        class: ::Components::InlineLinkBlock.item_class,
        data: { toggle: "modal", target: "##{@edit_modal_target}" }
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

      can_edit_object?
    end

    def can_destroy_location?
      return false unless @object.destroyable?

      in_admin_mode? || @object.user == @user
    end
  end
end
