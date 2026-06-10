# frozen_string_literal: true

# Action template for the Names index. Replaces
# `app/views/controllers/names/index.html.erb` + its per-row
# partial `_name.erb` + the alt-spellings alert
# `_name_suggestions.erb` (the last of which was already moved
# out of the misleading `show/` subdirectory in this branch).
#
# Composes:
#   - page chrome (container_class, index title, context-nav,
#     sorter, pagination)
#   - flash + optional `:needs_description` help blurb
#   - alt-spellings alert when the query returned no results AND
#     the controller fed back a list of suggested respellings
#   - paginated list of Name rows
#
# `NamesController#render_index_view` overrides the ApplicationController
# default to render this Phlex class directly with explicit props.
module Views::Controllers::Names
  class Index < Views::Base
    prop :query, ::Query::Names
    prop :pagination_data, ::PaginationData
    prop :objects,
         _Union(Array, ::ActiveRecord::Relation,
                ::ActiveRecord::Associations::CollectionProxy)
    prop :user, _Nilable(::User), default: nil
    prop :error, _Nilable(String), default: nil
    # The `needs_description` subaction sets `@help` to a
    # translation key Symbol; other subactions leave it nil.
    prop :help, _Nilable(Symbol), default: nil
    # Set by the `has_descriptions` subaction; per-row descriptions
    # columns render only when this is true.
    prop :has_descriptions, _Boolean, default: false
    # Pattern-search-with-zero-results path: the controller fills
    # this with alternate spellings to suggest.
    prop :name_suggestions, _Nilable(_Array(::Name)), default: nil
    # `test_index` action passes `{ anchor: … }` so the
    # pagination links carry a deep-link anchor.
    prop :test_pagination_args, _Hash(Symbol, String),
         default: -> { {} }

    def view_template
      container_class(:text_image)
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

      flash_error(@error) if @error && @objects.empty?

      render_suggestions_alert if suggest_alternates?
      render_help_blurb if @help

      paginated_results { render_name_rows }
    end

    private

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

    def render_name_rows
      return unless @objects.any?

      counts = Name.count_observations(@objects)
      render(Components::ListGroup.new(class: "name-index mb-3")) do |list|
        @objects.each do |name|
          list.item do
            render(Row.new(
                     name: name, user: @user, counts: counts,
                     has_descriptions: @has_descriptions
                   ))
          end
        end
      end
    end
  end
end
