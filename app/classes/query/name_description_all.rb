# frozen_string_literal: true

class Query::NameDescriptionAll < Query::NameDescriptionBase
  def parameter_declarations
    super.merge(
      old_by?: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_descriptions, params_plus_old_by)
  end
end
