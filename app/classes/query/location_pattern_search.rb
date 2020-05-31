# frozen_string_literal: true

class Query::LocationPatternSearch < Query::LocationBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    add_join(:"location_descriptions.default!")
    super
  end

  def search_fields
    "CONCAT(locations.name," +
      LocationDescription.all_note_fields.map do |x|
        "COALESCE(location_descriptions.#{x},'')"
      end.join(",") +
      ")"
  end
end
