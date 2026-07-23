# frozen_string_literal: true

# Copy-to-clipboard ID badge: a `<button>` with a clipboard tooltip,
# displayed next to an object's title (matrix box, project banner,
# species-list listing row, etc.). Clicking the badge copies the
# numeric id into the clipboard.
class Components::IDBadge < Components::Base
  prop :object, ::AbstractModel
  prop :extra_class, _Nilable(String), default: "mr-4"

  def view_template
    button(
      type: "button",
      class: class_names("badge badge-id", @extra_class),
      role: "button",
      data: {
        tooltip_target: "tip", placement: "bottom",
        title: :copy_this_id.ti,
        controller: "clipboard", clipboard_target: "source",
        action: "clipboard#copy",
        clipboard_copied_value: :copied.ti
      }
    ) do
      plain(@object.id&.to_s || "?")
    end
  end
end
