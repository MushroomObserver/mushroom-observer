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
      PaginatedResults { render_table }
    end

    def render_table
      Table(@matches, align_middle: true) do |t|
        t.column(:list_merge_options_mapped_locations.t) do |location|
          render_location_info(location)
        end
        t.column(:observations.ti, align: :right) do |location|
          Badge(variant: :count,
                count: @observation_counts[location.id].to_i)
        end
        t.column("#{:merge.ti}?", align: :right) do |location|
          render_merge_button(location)
        end
      end
    end

    def render_location_info(location)
      Link(type: :location, where: location.name.t, location: location)
    end

    def render_merge_button(location)
      Button(
        type: :patch,
        icon: :merge,
        name: :merge.ti,
        target: assign_location_to_observations_path(
          where: @where, location: location
        ),
        confirm: :list_merge_are_you_sure.l
      )
    end
  end
end
