# frozen_string_literal: true

# Action template for `Observations::LocationsController#edit` — the
# "list merge options" page. Despite the name, this isn't really a
# form: it's a paginated list of Location candidates, each rendered
# as a PATCH button that, when clicked, batch-assigns all observations
# sharing `@where` to the chosen Location.
module Views::Controllers::Observations::Locations
  class Edit < Views::Base
    prop :where, String
    prop :matches, _Array(::Location)
    prop :pagination_data, _Any
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:wide)
      add_page_title(
        :list_merge_options_title.t(
          where: ::Location.user_format(@user, @where)
        )
      )

      render_matches if @matches.any?
    end

    private

    def render_matches
      div(class: "h4") { plain(:list_merge_options_near_matches.t) }
      paginated_results do
        render(::Components::ListGroup.new) do |list|
          @matches.each { |location| render_match(list, location) }
        end
      end
    end

    def render_match(list, location)
      list.item do
        render(::Components::CrudButton::Patch.new(
                 name: location.display_name.t,
                 target: assign_location_to_observations_path(
                   where: @where, location: location
                 ),
                 class: "text-left",
                 data: { turbo_confirm: :list_merge_are_you_sure.l }
               ))
      end
    end
  end
end
