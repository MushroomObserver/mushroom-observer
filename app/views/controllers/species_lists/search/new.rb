# frozen_string_literal: true

module Views::Controllers::SpeciesLists
  module Search
    # Search form for species_lists. Wraps `Components::Form::Search`
    # with the page chrome (title, container width).
    class New < Views::FullPageBase
      def initialize(search:, controller:, local: nil)
        super()
        @search = search
        @controller = controller
        @local = local
      end

      def view_template
        add_new_title(:search_object, :species_lists)
        container_class(:wide)

        div(id: "species_lists_search_container") do
          render(Components::Form::Search.new(
                   @search,
                   search_controller: @controller,
                   local: @local != false
                 ))
        end
      end
    end
  end
end
