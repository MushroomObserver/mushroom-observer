# frozen_string_literal: true

# Action template for `Projects::SearchController#new` — the
# faceted projects-search form page. Replaces
# `app/views/controllers/projects/search/new.erb`. Renders
# `Components::SearchForm` against the controller's `@search`
# (a `Query::Projects` instance).
module Views::Controllers::Projects::Search
  class New < Views::Base
    prop :search, ::Query::Projects
    prop :local, _Boolean, default: true

    def view_template
      add_new_title(:search_object, :PROJECTS)
      container_class(:wide)

      div(id: "projects_search_container") do
        render(::Components::SearchForm.new(
                 @search,
                 search_controller: controller,
                 local: @local
               ))
      end
    end
  end
end
