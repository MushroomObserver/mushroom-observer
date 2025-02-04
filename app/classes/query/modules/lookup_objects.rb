# frozen_string_literal: true

# Helper methods to help parsing object instances from parameter strings.
module Query::Modules::LookupObjects
  def lookup_lists_for_projects_by_name(vals)
    Lookup::ProjectSpeciesLists.new(vals).ids
  end
end
