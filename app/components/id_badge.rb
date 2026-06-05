# frozen_string_literal: true

# Copy-to-clipboard ID badge: a `<button>` with a clipboard tooltip,
# displayed next to an object's title (matrix box, project banner,
# species-list listing row, etc.). Clicking the badge copies the
# numeric id into the clipboard.
#
# Replaces the `show_title_id_badge` helper that lived in
# `app/helpers/header/title_helper.rb`. Callers pass the object and
# optional extra CSS classes (defaults to `"mr-4"`).
class Components::IdBadge < Components::Base
  prop :object, ::AbstractModel
  prop :extra_class, _Nilable(String), default: "mr-4"

  def view_template
    button(
      type: "button",
      class: class_names("badge badge-id", @extra_class),
      role: "button",
      data: {
        toggle: "tooltip", placement: "bottom",
        title: :COPY_THIS_ID.l,
        controller: "clipboard", clipboard_target: "source",
        action: "clipboard#copy",
        clipboard_copied_value: :COPIED.l
      }
    ) do
      plain(@object.id&.to_s || "?")
    end
  end
end
