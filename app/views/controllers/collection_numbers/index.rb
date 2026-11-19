# frozen_string_literal: true

# Action template for the CollectionNumbers index.
#
# `CollectionNumbersController#render_index_view` overrides the
# `ApplicationController` default to render this class directly with
# explicit props.
module Views::Controllers::CollectionNumbers
  class Index < Views::FullPageBase
    prop :query, ::Query::CollectionNumbers
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::CollectionNumber)
    prop :user, ::User
    prop :observation, _Nilable(::Observation), default: nil

    def view_template
      container_class(:wide)
      add_index_title(@query)
      add_context_nav(
        Tab::CollectionNumber::IndexActions.new(observation: @observation)
      )
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      PaginatedResults do
        render_rows_table if @objects.any?
      end
    end

    private

    # Headerless `Components::Table` (`show_headers: false`).
    def render_rows_table
      Table(@objects, variant: :striped, show_headers: false) do |t|
        t.column("") { |cn| render_format_name_link(cn) }
        t.column("") { |cn| render_observation_links(cn) }
        t.column("") { |cn| render_actions(cn) }
      end
    end

    def render_actions(collection_number)
      InlineCRUDLinks(target: collection_number, observation: @observation,
                      user: @user)
    end

    def render_format_name_link(collection_number)
      i do
        Link(type: :object, object: collection_number,
             name: collection_number.format_name.t)
      end
    end

    def render_observation_links(collection_number)
      collection_number.observations.each_with_index do |obs, idx|
        plain(", ") if idx.positive?
        Link(type: :get, name: obs.unique_format_name.t,
             target: permanent_observation_path(obs)) do
          trusted_html(obs.unique_format_name.t)
        end
      end
    end
  end
end
