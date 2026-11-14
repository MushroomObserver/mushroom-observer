# frozen_string_literal: true

# Action template for the "Observations needing identification"
# index.
#
# Composes the page chrome (container width, index title, pagination
# with a "How To Use" collapse trigger in its sorter slot), then
# paginates a `Components::Matrix::Table` in `identify: true` mode
# (each row carries the vote-select / footer-buttons identify
# chrome).
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
      add_help_trigger_to_sorter_slot
      add_pagination(@pagination_data)

      Container(width: :text) { render_intro_collapsible }

      PaginatedResults { render_matrix }
    end

    private

    def intro_help_id
      "obs_needing_id_intro"
    end

    # No sort options on this index -- the help trigger takes the
    # pagination row's sorter slot, so it sits beside the pagination
    # controls instead of as a block above the results.
    def add_help_trigger_to_sorter_slot
      content_for(:sorter) { capture { render_help_trigger } }
    end

    def render_help_trigger
      div(class: "d-flex align-items-center") do
        plain(:app_how_to_use.t)
        Help(type: :collapse_info_trigger, target_id: intro_help_id,
             class: "ml-2")
      end
    end

    def render_intro_collapsible
      Collapsible(id: intro_help_id) do
        ContentPadded { Help { trusted_html(:obs_needing_id_intro.tp) } }
      end
    end

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
