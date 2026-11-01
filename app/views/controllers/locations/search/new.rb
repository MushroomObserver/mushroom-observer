# frozen_string_literal: true

module Views::Controllers::Locations
  module Search
    # Locations search form page.
    class New < Views::FullPageBase
      prop :search, ::Query
      prop :context, _Union(:page, :dropdown), default: :page

      def view_template
        add_new_title(:search_object, :locations)
        container_class(:wide)

        div(id: "locations_search_container") do
          render(::Components::Form::Search.new(
                   @search,
                   search_controller: controller,
                   context: @context
                 ))
        end
      end
    end
  end
end
