# frozen_string_literal: true

# Action template for `Names::MapsController#show`. Renders the
# observations map for a given Name, with a "cap exceeded" banner
# when the controller capped the result set.
class Views::Controllers::Names::Maps::Show < Views::Base
  register_value_helper :make_map
  register_value_helper :number_with_delimiter

  prop :name, ::Name
  prop :query, _Nilable(::Query::Observations), default: nil
  prop :observations,
       _Union(Array, ::ActiveRecord::Relation,
              ::ActiveRecord::Associations::CollectionProxy)
  prop :observations_capped, _Boolean, default: false
  prop :observations_loaded_count, Integer, default: 0
  prop :observations_total_count, Integer, default: 0
  prop :cluster_query_string, _Nilable(String), default: nil

  def view_template
    container_class(:full)
    add_page_title(:name_map_title.t(name: @name.display_name))
    add_context_nav(
      Tab::Name::MapActions.new(
        name: @name, query: @query, controller: controller
      )
    )

    render_cap_banner
    render_map
  end

  private

  def render_cap_banner
    div(id: "map_cap_banner",
        class: "alert alert-warning mt-2",
        style: @observations_capped ? nil : "display:none") do
      plain(
        :map_cap_banner.t(
          loaded: number_with_delimiter(@observations_loaded_count),
          total: number_with_delimiter(@observations_total_count)
        )
      )
    end
  end

  def render_map
    trusted_html(
      make_map(
        objects: @observations,
        clustering: true,
        capped: @observations_capped,
        cluster_query_string: @cluster_query_string,
        query_param: q_param(@query), zoom: 2, map_type: "info",
        nothing_to_map: :name_map_no_maps.tp(name: @name.display_name)
      )
    )
  end
end
