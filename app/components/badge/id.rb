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
# the external-links accordion pane passes a site-specific "Copy
# iNaturalist ID" so the badge reads unambiguously when an observation
# has several external-site ids next to each other.
#
# `size:` picks the badge's font-size modifier -- `.badge-id` itself
# has no inherent font-size, so every caller states its size
# explicitly rather than relying on an implicit default:
#   :xl -- project/species-list table row title badges
#          (Projects::ProjectTable, SpeciesLists::SpeciesListTable)
#   :lg -- copy-to-clipboard external-site record id (Link::External),
#          Matching Observations panel row ids
#   :md -- matrix box title and other index-row id badges (Grid::Box,
#          Names::Index, Occurrences::Projects::Form)
#   :sm -- sitting next to a large page-title heading
#
# `interactive:` (default true) is the copy-to-clipboard `<button>`
# described above. Pass `false` for a plain, non-clickable `<span>` --
# e.g. next to an object that isn't itself a link either (Matching
# Observations' current-observation row). Pass `link:` (a URL) instead
# for a badge that navigates -- e.g. the observation lightbox caption's
# id badge, which opens the observation on click.
#
# `class:` has no default margin -- omit it when the badge needs no
# spacing (e.g. a table/grid column), or pass `"mr-3"`/`"ml-2"`/etc.
# when it does.
#
# @example
#   Badge(variant: :id, object: @project, size: :sm, class: "mr-3")
class Components::Badge::ID < Components::Badge
  prop :object, _Nilable(::AbstractModel), default: nil
  prop :value, _Nilable(_Union(String, Integer)), default: nil
  prop :size, _Union(*Components::Badge::SIZES)
  prop :title, _Nilable(String), default: nil
  prop :interactive, _Boolean, default: true
  prop :link, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    if @link
      a(**badge_attributes, href: @link) { plain(display_value) }
    elsif @interactive
      render_interactive_badge
    else
      span(**badge_attributes) { plain(display_value) }
    end
  end

  private

  def render_interactive_badge
    button(**mix(badge_attributes, data: clipboard_data),
           type: "button", role: "button") do
      plain(display_value)
    end
  end

  def clipboard_data
    {
      tooltip_target: "tip", placement: "bottom",
      title: @title || :copy_this_id.ti,
      controller: "clipboard", clipboard_target: "source",
      action: "clipboard#copy",
      clipboard_copied_value: :copied.ti
    }
  end

  def badge_attributes
    mix({ class: class_names("badge badge-id",
                             Components::Badge.size_class(@size)) },
        @attributes)
  end

  def display_value
    (@object&.id || @value)&.to_s || "?"
  end
end
