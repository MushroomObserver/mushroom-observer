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
# Consume via `#to_a` (the `[title, url, opts]` tuple — used by
# `Components::NavTabs` and `add_context_nav`) or directly via
# `#title` / `#path` / `#html_options`.
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
#   Tab::Project::Summary.new(project: p).to_a
#   # => ["Summary", "/projects/123",
#   #     { class: "summary_link summary_link_123" }]
class Tab::Base
  include Rails.application.routes.url_helpers

  # Keys subclasses may return from `#html_options`. All others raise.
  ALLOWED_HTML_OPTION_KEYS = [:class, :id, :button, :back, :icon, :external,
                              :data, :title, :confirm].freeze

  # Valid values for the `:button` key.
  ALLOWED_BUTTON_VALUES = [:post, :put, :patch, :destroy].freeze

  # Auto-prepend `HtmlOptionsComposer` onto every subclass so the
  # subclass-supplied `#html_options` (or the Base default `{}`)
  # is wrapped with the auto-derived `<alt_title>_link` selector
  # class and validated against `ALLOWED_HTML_OPTION_KEYS`. Subclasses
  # define `html_options` returning the extra attrs they want
  # (`{ button: :post }`, `{ data: { action: "links#disable" } }`, etc.)
  # and the composition + validation happen transparently.
  def self.inherited(subclass)
    super
    subclass.prepend(HtmlOptionsComposer)
  end

  # Merges the auto-derived `<alt_title>_link` selector class
  # (or `<title>_<model_name>_link <…_link_<id>>` when `#model`
  # is set) into whatever `html_options` the subclass returned,
  # then validates keys against `ALLOWED_HTML_OPTION_KEYS`.
  # See `Tab::Base#derived_html_class` for the derivation rules.
  module HtmlOptionsComposer
    def html_options
      base = super.dup
      validate_html_options!(base)
      base[:class] = [base[:class], derived_html_class].
                     compact_blank.join(" ")
      base
    end

    private

    def validate_html_options!(opts)
      unknown = opts.keys - ALLOWED_HTML_OPTION_KEYS
      if unknown.any?
        raise(ArgumentError.new(
                "#{self.class}#html_options unknown key(s): " \
                "#{unknown.map(&:inspect).join(", ")}. " \
                "Allowed: #{ALLOWED_HTML_OPTION_KEYS.join(", ")}"
              ))
      end

      return unless (btn = opts[:button])
      return if ALLOWED_BUTTON_VALUES.include?(btn)

      raise(ArgumentError.new(
              "#{self.class}#html_options :button must be one of " \
              "#{ALLOWED_BUTTON_VALUES.join(", ")}, got #{btn.inspect}"
            ))
    end
  end

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

  # Override to return a model (instance or class) when the Tab's
  # selector class should include the model name + per-id flavour
  # — e.g. `edit_project_alias_link edit_project_alias_link_123`.
  # Plain Tab POROs leave this nil and get a single
  # `<title|alt_title>_link` class. See `#derived_html_class` for
  # the derivation rules.
  def model
    nil
  end

  def to_a
    [title, path, html_options]
  end

  # Append a `q=<value>` query param to a path string. Pass the
  # caller-side `q_param` (already resolved — Tab POROs are
  # request-agnostic, so the caller is responsible for asking the
  # request context what `q_param` is). When `q_param_value` is nil
  # or blank, the original path returns unchanged.
  #
  # Use from a Tab PORO's `#path` method when the tab's URL needs to
  # carry the current Query through (e.g. "back to filtered index"
  # links on a show page).
  #
  # Accepts either:
  # - a String q_param (the alphabetized-id form — `?q=ABCDE`), or
  # - a Hash q_param (the model+params form returned by
  #   `Query#q_param` — `?q[model]=Observation&q[locations][]=1`)
  #
  # Uses Rails' `Hash#to_query` (not `Rack::Utils.build_query`)
  # because Rack stringifies a nested Hash value as a literal Ruby
  # `inspect` rep; `to_query` recurses correctly into nested
  # hashes and arrays. Caught by the related_records integration
  # tests that exercise `Tab::Location::ObservationsAt` — Query#q_param
  # returns a Hash for newly-created queries, and the resulting URL
  # was an unparseable literal Ruby Hash rep encoded with `+` for
  # whitespace.
  def with_q_param(path, q_param_value)
    return path if q_param_value.blank?

    uri = URI.parse(path)
    parsed = uri.query ? Rack::Utils.parse_query(uri.query) : {}
    parsed["q"] = q_param_value
    uri.query = parsed.to_query
    uri.to_s
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

  private

  # Auto-derived selector class merged into `html_options[:class]` by
  # `HtmlOptionsComposer`. Test selectors and JS hooks across the app
  # depend on this naming pattern, so the derivation is kept stable.
  def derived_html_class
    model ? model_html_class : plain_html_class
  end

  def plain_html_class
    "#{(alt_title || title).parameterize(separator: "_")}_link"
  end

  # Model-aware flavour: includes the model name in the slug (so the
  # same `:EDIT.t` title on different models produces distinct
  # classes) and, when the model has an `id`, a second
  # `…_link_<id>` per-instance class for ID-pinned selectors.
  def model_html_class
    slug = model_class_slug
    return slug unless model.respond_to?(:id) && model.id

    "#{slug} #{slug}_#{model.id}"
  end

  def model_class_slug
    raw = if alt_title
            alt_title
          elsif title.underscore.tr(" ", "_").include?(model_name_for_class)
            title
          else
            "#{title}_#{model_name_for_class}"
          end
    "#{raw.parameterize(separator: "_")}_link"
  end

  def model_name_for_class
    klass = model.is_a?(Class) ? model : model.class
    klass.name.underscore
  end
end
