# frozen_string_literal: true

class Query::NameDescriptionAll < Query::NameDescriptionBase
  def parameter_declarations
    super.merge(
      old_by?: :string,
      with_descriptions?: :boolean
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_name_query
    pargs = params_out_to_with_descriptions_params
    Query.lookup(:Name, :all, pargs)
  end
end
