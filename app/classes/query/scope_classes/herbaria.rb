# frozen_string_literal: true

class Query::ScopeClasses::Herbaria < Query::BaseAR
  def model
    Herbarium
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [Herbarium],
      code_has: :string,
      name_has: :string,
      description_has: :string,
      mailing_address_has: :string,
      pattern: :string,
      nonpersonal: :boolean
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_time_stamp_conditions
    add_simple_search_condition(:code)
    add_simple_search_condition(:name)
    add_simple_search_condition(:description)
    add_simple_search_condition(:mailing_address)
    add_id_in_set_condition
    add_nonpersonal_condition
    add_pattern_condition
    super
  end

  def add_nonpersonal_condition
    return if params[:nonpersonal].blank?

    @title_tag = :query_title_nonpersonal
    @scopes = @scopes.nonpersonal
  end

  def search_fields
    (Herbarium[:code] + Herbarium[:name] +
     Herbarium[:description].coalesce("") +
     Herbarium[:mailing_address].coalesce(""))
  end

  def self.default_order
    :name
  end
end
