# frozen_string_literal: true

# Helper methods to help parsing object instances from parameter strings.
module Query::Modules::LookupObjects
  def lookup_external_sites_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      ExternalSite.where(name: name)
    end
  end

  def lookup_herbaria_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      Herbarium.where(name: name)
    end
  end

  def lookup_herbarium_records_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      HerbariumRecord.where(id: name)
    end
  end

  def lookup_locations_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      pattern = Location.clean_name(name).clean_pattern
      Location.where("name LIKE ?", "%#{pattern}%")
    end
  end

  def lookup_projects_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      Project.where(title: name)
    end
  end

  def lookup_lists_for_projects_by_name(vals)
    return unless vals

    project_ids = lookup_projects_by_name(vals)
    return [] if project_ids.empty?

    SpeciesList.joins(:project_species_lists).
      where(project_species_lists: { project_id: project_ids }).distinct.
      map(&:id)
  end

  def lookup_species_lists_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      SpeciesList.where(title: name)
    end
  end

  def lookup_users_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      User.where(login: User.remove_bracketed_name(name))
    end
  end

  # ------------------------------------------------------------------------

  private

  def lookup_objects_by_name(vals)
    return unless vals

    vals.map do |val|
      if /^\d+$/.match?(val.to_s)
        val
      else
        yield(val).map(&:id)
      end
    end.flatten.uniq.compact
  end
end
