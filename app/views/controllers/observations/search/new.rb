# frozen_string_literal: true

# Action template for `Observations::SearchController#new` — the
# faceted observations-search form page. Renders
# `Components::Form::Search` against the controller's `@search`
# (a `Query::Observations` instance).
#
# The `new` action in `Searchable` always sets `@context` (:dropdown
# only for `params[:local] == "false"`); the prop default just
# matches the "render full chrome" semantic in case a future caller
# constructs this view without going through the action.
module Views::Controllers::Observations::Search
  class New < Views::FullPageBase
    prop :search, ::Query::Observations
    prop :context, _Union(:page, :dropdown), default: :page

    def view_template
      add_new_title(:search_object, :observations)
      container_class(:wide)

      div(id: "observations_search_container") do
        render(::Components::Form::Search.new(
                 @search,
                 search_controller: controller,
                 context: @context
               ))
      end
    end
  end
end
