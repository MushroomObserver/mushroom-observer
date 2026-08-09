# frozen_string_literal: true

module Views::Controllers::Herbaria::Search
  # Action view for the herbaria search form page.
  class New < Views::FullPageBase
    prop :search, ::Query
    prop :controller, ::Herbaria::SearchController
    prop :local, _Boolean

    def view_template
      add_new_title(:search_object, :herbaria)
      container_class(:wide)

      div(id: "herbaria_search_container") do
        render(Components::Form::Search.new(
                 @search,
                 search_controller: @controller,
                 local: @local != false
               ))
      end
    end
  end
end
