# frozen_string_literal: true

# Action template for the "Observations needing identification"
# index.
#
# Composes the page chrome (container width, index title,
# pagination), flashes the no-matches error when the query
# returned nothing, renders the intro blurb, then paginates a
# `Components::Matrix::Table` in `identify: true` mode (each row
# carries the vote-select / footer-buttons identify chrome).
#
# `Observations::IdentifyController#render_index_view` overrides
# the `ApplicationController` default to render this class
# directly with explicit props.
module Views::Controllers::Observations::Identify
  class Index < Views::FullPageBase
    prop :query, ::Query::Observations
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Observation)
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:full)
      add_index_title(@query)
      add_pagination(@pagination_data)

      Container(width: :text) do
        ContentPadded do
          p { trusted_html(:obs_needing_id_intro.tp) }
        end
      end

      PaginatedResults { render_matrix }
    end

    private

    def render_matrix
      render(Components::Matrix::Table.new(
               objects: @objects,
               user: @user,
               identify: true,
               cached: true
             ))
    end
  end
end
