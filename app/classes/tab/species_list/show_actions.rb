# frozen_string_literal: true

# Action-tab strip rendered above the species-list show page's
# observation listing: Map, Observations, Names always; Locations
# and Images only when the active query supports the
# Location-via-Observation bridge (the related-query for those two
# cross-domain indexes -- both gated on that single check, not on
# each model's relation separately). Observations/Names/Locations
# show counts, matching Tab::Project::Banner; Images doesn't -- no
# cheap count source exists for it the way `name_and_location_counts`
# gives the other two.
class Tab::SpeciesList::ShowActions < Tab::Collection
  def initialize(species_list:, project:, query:, controller:,
                 observations_count:)
    super()
    @species_list = species_list
    @project = project
    @query = query
    @controller = controller
    @observations_count = observations_count
  end

  private

  def tabs
    [
      Tab::SpeciesList::Map.new(q_param: q_param),
      Tab::SpeciesList::Observations.new(q_param: q_param,
                                         count: @observations_count),
      Tab::SpeciesList::Names.new(species_list: @species_list,
                                  project: @project,
                                  count: name_and_location_counts[0]),
      *related_query_tabs
    ]
  end

  def q_param
    @q_param ||= @controller.q_param(@query)
  end

  def related_query_tabs
    return [] unless @query && Query.related?(:Location, :Observation)

    [
      Tab::SpeciesList::Locations.new(
        query: @query, controller: @controller,
        count: name_and_location_counts[1]
      ),
      Tab::SpeciesList::Images.new(query: @query, controller: @controller)
    ]
  end

  # One query, computed in SQL -- two Arel `COUNT(DISTINCT ...)`
  # nodes in a single `pick`, instead of two separate
  # `.distinct.count(:name_id)` / `.distinct.count(:location_id)`
  # round trips, or pulling every observation row into Ruby to
  # dedupe. `Attribute#count(true)` is Arel's distinct-count builder:
  # it wraps the column in an `Arel::Nodes::Count` node with its
  # `distinct` flag set, which the SQL visitor renders as
  # `COUNT(DISTINCT column)` (`count` with no arg, or `false`,
  # renders plain `COUNT(column)`).
  def name_and_location_counts
    @name_and_location_counts ||= @species_list.observations.pick(
      Observation.arel_table[:name_id].count(true),
      Observation.arel_table[:location_id].count(true)
    )
  end
end
