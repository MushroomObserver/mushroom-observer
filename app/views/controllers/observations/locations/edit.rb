# frozen_string_literal: true

# Action template for `Observations::LocationsController#edit` — the
# "list merge options" page: a paginated list of Location candidates,
# each a row with a Merge button that batch-assigns all observations
# sharing `@where` to that Location.
module Views::Controllers::Observations::Locations
  class Edit < Views::FullPageBase
    prop :where, String
    prop :matches, _Array(::Location)
    prop :observation_counts, _Hash(::Integer, ::Integer)
    prop :pagination_data, ::PaginationData
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:wide)
      content_padding(:panels)
      add_page_title(
        :list_merge_options_title.t(
          where: ::Location.user_format(@user, @where)
        )
      )

      render_matches if @matches.any?
    end

    private

    def render_matches
      div(class: "h4 pl-card") { plain(:list_merge_options_near_matches.t) }
      PaginatedResults do
        ListGroup do |list|
          @matches.each { |location| render_match(list, location) }
        end
      end
    end

    def render_match(list, location)
      list.item(class: "d-flex align-items-center justify-content-between") do
        render_location_info(location)
        render_merge_button(location)
      end
    end

    def render_location_info(location)
      div(class: "d-flex align-items-center") do
        Link(type: :location, where: location.name.t, location: location)
        div(class: "ml-3") do
          CountBadge(count: @observation_counts[location.id].to_i)
        end
      end
    end

    def render_merge_button(location)
      div(class: "ml-3") do
        Button(
          type: :patch,
          variant: :outline,
          icon: :merge,
          name: :merge.ti,
          show_label: :responsive,
          target: assign_location_to_observations_path(
            where: @where, location: location
          ),
          confirm: :list_merge_are_you_sure.l
        )
      end
    end
  end
end
