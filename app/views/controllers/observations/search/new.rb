# frozen_string_literal: true

# Action template for `Observations::SearchController#new` — the
# faceted observations-search form page. Replaces `new.erb`. Renders
# `Components::SearchForm` against the controller's `@search`
# (a `Query::Observations` instance).
#
# The `new` action in `Searchable` always sets `@local` (the
# inverse of `params[:local] == "false"`); the prop default just
# matches that "render full chrome" semantic in case a future caller
# constructs this view without going through the action.
module Views::Controllers::Observations::Search
  class New < Views::Base
    prop :search, ::Query::Observations
    prop :local, _Boolean, default: true

    def view_template
      add_new_title(:search_object, :OBSERVATIONS)
      container_class(:wide)

      div(id: "observations_search_container") do
        render(::Components::SearchForm.new(
                 @search,
                 search_controller: controller,
                 local: @local
               ))
      end
    end
  end
end
