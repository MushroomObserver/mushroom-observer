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
      pattern = clean_pattern(Location.clean_name(name))
      Location.where("name LIKE ?", "%#{pattern}%")
    end
  end

  def lookup_names_by_name(vals, filter = nil)
    return unless vals

    vals.map do |val|
      if /^\d+$/.match?(val.to_s)
        if filter
          Name.safe_find(val).send(filter).map(&:id)
        else
          val
        end
      elsif filter
        find_matching_names(val).map { |x| x.send(filter) }.flatten.map(&:id)
      else
        find_matching_names(val).map(&:id)
      end
    end.flatten.uniq.reject(&:nil?)
  end

  def lookup_projects_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      Project.where(title: name)
    end
  end

  def lookup_species_lists_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      SpeciesList.where(title: name)
    end
  end

  def lookup_users_by_name(vals)
    lookup_objects_by_name(vals) do |name|
      User.where(login: name.sub(/ *<.*>/, ""))
    end
  end

  # ----------------------------------------------------------------------------

  private

  def lookup_objects_by_name(vals)
    return unless vals

    vals.map do |val|
      if /^\d+$/.match?(val.to_s)
        val
      else
        yield(val).map(&:id)
      end
    end.flatten.uniq.reject(&:nil?)
  end

  def find_matching_names(name)
    parse = Name.parse_name(name)
    name2 = parse ? parse.search_name : Name.clean_incoming_string(name)
    matches = Name.where(search_name: name2)
    matches = Name.where(text_name: name2) if matches.empty?
    matches
  end
end
