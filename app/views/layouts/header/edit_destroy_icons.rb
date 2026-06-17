# frozen_string_literal: true

# Page-title-bar edit/destroy icons. Renders a pair of `<li>` items
# with the CrudButton::Edit + CrudButton::Delete buttons, gated by
# what the viewer can do to the object. Empty render when the viewer
# has no permissions — the parent `<ul>` in
# `Views::Layouts::Header::PageTitle` always renders so the flex
# layout reserves the right-side slot even when no icons fire.
#
# Rendered into `content_for(:edit_icons)` by
# `Header::InterestAndEditIconsHelper#add_edit_icons`.
#
# `Location` has a stricter destroy gate (model `destroyable?` + the
# viewer owns the record or is in admin mode); other models follow
# the edit-permission shape.
module Views::Layouts
  class Header::EditDestroyIcons < Views::Base
    prop :object, ::AbstractModel
    prop :user, _Nilable(::User), default: nil

    def view_template
      li { render_edit_button } if can_edit_object?
      li { render_destroy_button } if can_destroy_object?
    end

    private

    def render_edit_button
      render(::Components::CrudButton::Edit.new(
               target: @object, btn: nil
             ))
    end

    def render_destroy_button
      render(::Components::CrudButton::Delete.new(
               target: @object, btn: nil
             ))
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
