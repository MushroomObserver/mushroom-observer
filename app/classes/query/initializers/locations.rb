# frozen_string_literal: true

module Query::Initializers::Locations
  def initialize_location_notes_parameters
    add_boolean_condition("LENGTH(COALESCE(locations.notes,'')) > 0",
                          "LENGTH(COALESCE(locations.notes,'')) = 0",
                          params[:with_notes])
    add_search_condition("locations.notes", params[:notes_has])
  end

  def add_regexp_condition
    return if params[:regexp].blank?

    @title_tag = :query_title_regexp_search
    regexp = escape(params[:regexp].to_s.strip_squeeze)
    where << "locations.name REGEXP #{regexp}"
  end
end
