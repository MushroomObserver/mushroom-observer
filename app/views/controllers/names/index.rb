# frozen_string_literal: true

# Action template for the Names index.
#
# Composes:
#   - page chrome (container_class, index title, context-nav,
#     sorter, pagination)
#   - flash + optional `:needs_description` help blurb
#   - alt-spellings alert when the query returned no results AND
#     the controller fed back a list of suggested respellings
#   - paginated table of Names: MO ID / Name (with a copy-to-
#     clipboard icon) / Observations, plus Authors / Notes / Status
#     columns when the active query filters on `has_descriptions`
#
# `NamesController#render_index_view` overrides the ApplicationController
# default to render this Phlex class directly with explicit props.
module Views::Controllers::Names
  class Index < Views::FullPageBase
    prop :query, ::Query::Names
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Name)
    prop :user, _Nilable(::User), default: nil
    # A translation key Symbol when the active query filters on
    # `needs_description`; nil otherwise.
    prop :help, _Nilable(Symbol), default: nil
    # True when the active query filters on `has_descriptions`;
    # per-row Authors/Notes/Status columns render only then.
    prop :has_descriptions, _Boolean, default: false
    # Pattern-search-with-zero-results path: the controller fills
    # this with alternate spellings to suggest.
    prop :name_suggestions, _Nilable(_Array(::Name)), default: nil
    # `test_index` action passes `{ anchor: … }` so the
    # pagination links carry a deep-link anchor.
    prop :test_pagination_args, _Hash(Symbol, String),
         default: -> { {} }

    def view_template
      register_chrome
      render_names
    end

    private

    def register_chrome
      container_class(:full)
      add_index_title(@query)
      add_context_nav(
        Tab::Name::IndexActions.new(
          query: @query, controller: controller
        )
      )
      # Sort table lives on the controller —
      # `NamesController#index_sort_options` — single source of truth.
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data, @test_pagination_args)
    end

    def render_names
      render_suggestions_alert if suggest_alternates?
      render_help_blurb if @help

      PaginatedResults { render_name_table }
    end

    def suggest_alternates?
      @objects.empty? && @name_suggestions&.any?
    end

    def render_suggestions_alert
      render(NameSuggestionsAlert.new(
               names: @name_suggestions, user: @user
             ))
    end

    def render_help_blurb
      trusted_html(@help.tp)
    end

    def render_name_table
      return unless @objects.any?

      counts = Name.count_observations(@objects)
      Table(@objects, identifier: "name-index") do |t|
        t.column(:mo_id.ti) { |name| IDBadge(object: name, size: :md) }
        t.column(:name.ti) { |name| render_name_cell(name) }
        t.column(:sort_by_observations.t, align: :right) do |name|
          CountBadge(count: counts[name.id].to_i)
        end
        render_description_columns(t) if @has_descriptions
      end
    end

    def render_name_cell(name)
      span(
        data: { controller: "clipboard",
                clipboard_copied_value: :copied.ti }
      ) do
        a(href: name_path(name.id)) do
          span(class: "display-name",
               data: { clipboard_target: "source" }) do
            trusted_html(name.display_name(@user).t)
          end
        end
        render_copy_button
      end
    end

    def render_copy_button
      Button(
        variant: :link,
        class: "py-0 link-normal opacity-75",
        role: "button",
        data: { tooltip_target: "tip", placement: "bottom",
                title: :copy_this_name.ti,
                action: "clipboard#copy" }
      ) { Icon(type: :copy) }
    end

    # `has_descriptions` subaction columns: when a default description
    # exists, show its authors / note status / review status; when it
    # doesn't, the Authors cell carries the placeholder text.
    def render_description_columns(table)
      table.column(:authors.ti) { |name| description_authors(name) }
      table.column(:notes.ti) { |name| description_note_status(name) }
      table.column(:status.ti) { |name| description_review_status(name) }
    end

    def description_authors(name)
      desc = name.description
      return "--- not the default ---" unless desc

      desc.authors.map(&:login).join(", ")
    end

    def description_note_status(name)
      name.description&.note_status&.join("/")
    end

    def description_review_status(name)
      desc = name.description
      return unless desc

      :"review_#{desc.review_status}".l
    end
  end
end
