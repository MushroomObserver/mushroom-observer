# frozen_string_literal: true

module Views::Controllers::Herbaria::Search
  # Action view for the herbaria search form page. Replaces new.erb.
  class New < Views::Base
    def initialize(search:, controller:, local:)
      super()
      @search = search
      @controller = controller
      @local = local
    end

    def view_template
      add_new_title(:search_object, :HERBARIA)
      container_class(:wide)

      div(id: "herbaria_search_container") do
        render(Components::SearchForm.new(
                 @search,
                 search_controller: @controller,
                 local: @local != false
               ))
      end
    end
  end
end
