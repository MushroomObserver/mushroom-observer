# frozen_string_literal: true

# Helper methods to help parsing object instances from parameter strings.
module Query::Modules::LookupObjects
  def lookup_external_sites_by_name(vals)
    Lookup::ExternalSites.new(vals).ids
  end

  def lookup_field_slips_by_name(vals)
    Lookup::FieldSlips.new(vals).ids
  end

  def lookup_herbaria_by_name(vals)
    Lookup::Herbaria.new(vals).ids
  end

  def lookup_herbarium_records_by_name(vals)
    Lookup::HerbariumRecords.new(vals).ids
  end

  def lookup_locations_by_name(vals)
    Lookup::Locations.new(vals).ids
  end

  def lookup_names_by_name(vals, params = {})
    Lookup::Names.new(vals, **params).ids
  end

  def lookup_projects_by_name(vals)
    Lookup::Projects.new(vals).ids
  end

  def lookup_lists_for_projects_by_name(vals)
    Lookup::ProjectSpeciesLists.new(vals).ids
  end

  def lookup_species_lists_by_name(vals)
    Lookup::SpeciesLists.new(vals).ids
  end

  def lookup_users_by_name(vals)
    Lookup::Users.new(vals).ids
  end
end
