# frozen_string_literal: true

# Page-title-bar edit/delete icons. Renders a `<ul>` with edit +
# delete buttons gated by what the viewer can do to the object.
# Always emits the `<ul>` — empty when the viewer has no permissions —
# so the parent flex layout in `Views::Layouts::Header::PageTitle`
# is consistent regardless of permission state.
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
      ul(class: "nav d-flex align-items-center " \
                "justify-content-end mt-0 h4 object_edit") do
        li { render_edit_button } if can_edit_object? && !read_only_reflection?
        li { render_delete_button } if can_destroy_object?
      end
    end

    private

    def render_edit_button
      render(::Components::Button::Edit.new(
               target: @object, variant: :strip
             ))
    end

    def render_delete_button
      render(::Components::Button::Delete.new(
               target: @object, variant: :strip
             ))
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
