# frozen_string_literal: true

# Base class for tab definitions. A Tab knows its title, URL, and any
# selector / identifier classes; it does NOT know its active state or
# its rendering chrome (that's `Components::NavTabs` and the consuming
# view's job).
#
# Subclasses live under `Tab::<Domain>::<Name>` at
# `app/classes/tab/<domain>/<name>.rb` and implement:
#
#   #title          — String (usually a `:FOO.t` lookup)
#   #path           — String (a route helper result, e.g. `project_path(id:)`)
#   #alt_title      — String, optional. Overrides the auto-derived
#                     selector class. Use when `title` includes a
#                     count ("3 Observations" → set
#                     `alt_title: "observations"` so the test
#                     selector class stays stable across counts).
#   #html_options   — Hash, optional. Extra attrs forwarded to the
#                     rendered `<a>` — id, data-*, behavior classes.
#                     Bootstrap nav-tab classes (`nav-link`, `active`,
#                     `mt-3`) belong to `NavTabs`, NOT here.
#
# Consume via `#to_internal_link` (NavTabs and other PORO callers) or
# `#to_a` (legacy `[title, url, opts]` consumers — the helper-method
# splat pattern from the helpers/tabs/* era).
#
# @example
#   class Tab::Project::Summary < Tab::Base
#     def initialize(project:)
#       @project = project
#     end
#
#     def title = :SUMMARY.t
#     def path = project_path(id: @project.id)
#     def alt_title = "summary"
#   end
#
#   Tab::Project::Summary.new(project: p).to_internal_link
#   # => #<InternalLink title="Summary" url="/projects/123" …>
class Tab::Base
  include Rails.application.routes.url_helpers

  def title
    raise(NotImplementedError.new("#{self.class}#title"))
  end

  def path
    raise(NotImplementedError.new("#{self.class}#path"))
  end

  def alt_title
    nil
  end

  def html_options
    {}
  end

  # Override to return a model (instance or class) when the Tab
  # should use the `InternalLink::Model` variant — its `html_class`
  # adds a `<model_name>` segment to the selector class (e.g.
  # `edit_project_alias_link`) and, for instances, a per-id flavour
  # (`edit_project_alias_link_123`). Plain Tab POROs leave this nil
  # and get a plain `InternalLink`.
  def model
    nil
  end

  def to_internal_link
    if model
      InternalLink::Model.new(title, model, path,
                              html_options: html_options,
                              alt_title: alt_title)
    else
      InternalLink.new(title, path,
                       html_options: html_options,
                       alt_title: alt_title)
    end
  end

  def to_a
    to_internal_link.tab
  end

  # Stable key NavTabs matches against `current:` to decide `.active`.
  # Defaults to `alt_title` when set (the same short identifier used
  # for the selector class) — this aligns with the existing MO
  # convention of `active_project_tab` / `current_subtab` carrying
  # short forms like "details", "members", "aliases", etc. Falls back
  # to the demodulized class name underscored when `alt_title` is nil.
  #
  # Override per subclass when the consuming view's current-tab
  # semantic differs from `alt_title`. Example: `Tab::Project::Summary`
  # has `alt_title: "summary"` (for the selector class) but its
  # `nav_key: "projects"` (because the project banner's `current_tab`
  # is derived from the controller_name, which is "projects" on the
  # project show page).
  def nav_key
    alt_title || self.class.name.demodulize.underscore
  end
end
