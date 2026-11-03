# frozen_string_literal: true

# Action-tab strip rendered above the species-list show page's
# observation listing: Map, Observations, Names always; Locations
# and Images only when the active query supports the
# Location-via-Observation bridge (the related-query for those two
# cross-domain indexes -- both gated on that single check, not on
# each model's relation separately). Observations/Names/Locations
# show counts, matching Tab::Project::Banner; Images doesn't -- no
# cheap count source exists for it the way `pluck` gives the other
# two.
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

  # One query instead of two separate `.distinct.count(:name_id)` /
  # `.distinct.count(:location_id)` calls -- pluck both columns in a
  # single pass over the list's observations, dedupe in Ruby.
  def name_and_location_counts
    @name_and_location_counts ||= begin
                                    rows = @species_list.observations.pluck(
                                      :name_id, :location_id
                                    )
                                    [rows.map(&:first).uniq.size,
                                     rows.map(&:last).uniq.size]
                                  end
  end
end
