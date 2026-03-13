# frozen_string_literal: true

class Lookup::ProjectSpeciesLists < Lookup
  MODEL = SpeciesList
  TITLE_METHOD = :title

  def initialize(vals, params = {})
    super
  end

  def ids
    @ids ||= lookup_method.map(&:id)
  end

  def instances
    @instances ||= lookup_method
  end

  def lookup_method
    # We're checking species_lists for each project.
    project_ids = Lookup::Projects.new(@vals).ids
    return [] if project_ids.empty?

    # Have to map(&:id) because it doesn't return lookup_object_ids_by_name
    SpeciesList.joins(:project_species_lists).
      where(project_species_lists: { project_id: project_ids }).distinct
  end
end
