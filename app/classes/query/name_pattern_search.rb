# frozen_string_literal: true

class Query::NamePatternSearch < Query::NameBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    add_join(:"name_descriptions.default!")
    super
  end

  def search_fields
    fields = [
      "names.search_name",
      "COALESCE(names.citation,'')",
      "COALESCE(names.notes,'')"
    ] + Name::Description.all_note_fields.map do |x|
      "COALESCE(name_descriptions.#{x},'')"
    end
    "CONCAT(#{fields.join(",")})"
  end
end
