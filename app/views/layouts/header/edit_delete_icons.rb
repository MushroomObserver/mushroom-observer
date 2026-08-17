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

    def view_template
      div(class: "h4 my-0 d-flex align-items-center object_edit") do
        InlineLinkBlock(items: [edit_item, delete_item].compact)
      end
    end

    private

    def edit_item
      return nil unless can_edit_object? && !read_only_reflection?

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

    # A read-only reflection (#4214) can't have its scalar core edited on
    # MO, so no edit icon -- change it at the source and resync. Delete is
    # a separate lifecycle concern and stays available.
    def read_only_reflection?
      @object.respond_to?(:reflection?) && @object.reflection?
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
