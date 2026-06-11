# frozen_string_literal: true

# Action template for `Names::MapsController#show`. Renders the
# observations map for a given Name. The cap banner used to be
# inline here; it's now baked into `Components::Map`, so we just
# instantiate the component with `clustering: true` and the
# `observations_*_count` props.
class Views::Controllers::Names::Maps::Show < Views::Base
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
      ::Tab::Name::MapActions.new(
        name: @name, query: @query, controller: controller
      )
    )

    render(::Components::Map.new(
             objects: @observations.to_a,
             clustering: true,
             capped: @observations_capped,
             observations_loaded_count: @observations_loaded_count,
             observations_total_count: @observations_total_count,
             cluster_query_string: @cluster_query_string,
             zoom: 2,
             map_type: "info",
             nothing_to_map: :name_map_no_maps.tp(name: @name.display_name)
           ))
  end
end
