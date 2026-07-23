# frozen_string_literal: true

# Copy-to-clipboard ID badge: a `<button>` with a clipboard tooltip,
# displayed next to an object's title (matrix box, project banner,
# species-list listing row, etc.). Clicking the badge copies the
# numeric id into the clipboard.
#
# Pass `object:` for an AbstractModel's own id (the common case), or
# `value:` for an id that isn't an AbstractModel's id at all -- e.g.
# an external site's numeric id shown next to an ExternalLink.
#
# `title:` overrides the tooltip text (default "Copy this ID") -- e.g.
# Link::External passes a site-specific "Copy iNaturalist ID" so
# the badge reads unambiguously when an observation has several
# external-site ids next to each other.
#
# `size:` picks the badge's font-size modifier -- `.badge-id` itself
# has no inherent font-size, so every caller states its size
# explicitly rather than relying on an implicit default:
#   :xl -- uppercase site-abbreviation accordion triggers ("iNat", "MCP")
#   :lg -- copy-to-clipboard external-site record id (Link::External)
#   :md -- rss-feed-style contexts (matrix box title, list rows)
#   :sm -- sitting next to a large page-title heading
class Components::IDBadge < Components::Base
  SIZE_CLASSES = { xl: "badge-xl", lg: "badge-lg",
                   md: "badge-md", sm: "badge-sm" }.freeze

  prop :object, _Nilable(::AbstractModel), default: nil
  prop :value, _Nilable(_Union(String, Integer)), default: nil
  prop :size, _Union(*SIZE_CLASSES.keys)
  prop :title, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: "mr-4"

  def view_template
    button(
      type: "button",
      class: class_names("badge badge-id", SIZE_CLASSES[@size], @extra_class),
      role: "button",
      data: {
        tooltip_target: "tip", placement: "bottom",
        title: @title || :copy_this_id.ti,
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
