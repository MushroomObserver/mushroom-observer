# frozen_string_literal: true

# Copy-to-clipboard ID badge: a `<button>` with a clipboard tooltip,
# displayed next to an object's title (matrix box, project banner,
# species-list listing row, etc.). Clicking the badge copies the
# numeric id into the clipboard.
#
# Pass `object:` for an AbstractModel's own id (the common case), or
# `value:` for an id that isn't an AbstractModel's id at all -- e.g.
# an external site's numeric id shown next to an ExternalLink.
class Components::IDBadge < Components::Base
  prop :object, _Nilable(::AbstractModel), default: nil
  prop :value, _Nilable(_Union(String, Integer)), default: nil
  prop :extra_class, _Nilable(String), default: "mr-4"

  def view_template
    button(
      type: "button",
      class: class_names("badge badge-id", @extra_class),
      role: "button",
      data: {
        trigger: "tooltip", placement: "bottom",
        title: :copy_this_id.ti,
        controller: "clipboard", clipboard_target: "source",
        action: "clipboard#copy",
        clipboard_copied_value: :copied.ti
      }
    ) do
      plain(display_value)
    end
  end

  private

  def display_value
    (@object&.id || @value)&.to_s || "?"
  end
end
