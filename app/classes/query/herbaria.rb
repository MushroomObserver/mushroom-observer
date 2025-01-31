# frozen_string_literal: true

class Query::Herbaria < Query::Base
  def model
    Herbarium
  end

  def parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      code: :string,
      name: :string,
      ids: [Herbarium],
      description: :string,
      address: :string,
      pattern: :string,
      nonpersonal: :boolean
    )
  end

  # rubocop:disable Metrics/AbcSize
  def initialize_flavor
    add_sort_order_to_title
    add_time_condition("herbaria.created_at", params[:created_at])
    add_time_condition("herbaria.updated_at", params[:updated_at])
    add_search_condition("herbaria.code", params[:code])
    add_search_condition("herbaria.name", params[:name])
    add_search_condition("herbaria.description", params[:description])
    add_search_condition("herbaria.mailing_address", params[:address])
    add_ids_condition
    add_pattern_condition
    add_nonpersonal_condition
    super
  end
  # rubocop:enable Metrics/AbcSize

  def add_nonpersonal_condition
    return if params[:nonpersonal].blank?

    @title_tag = :query_title_nonpersonal
    where << "herbaria.personal_user_id IS NULL"
  end

  def search_fields
    "CONCAT(" \
      "herbaria.code," \
      "herbaria.name," \
      "COALESCE(herbaria.description,'')," \
      "COALESCE(herbaria.mailing_address,'')" \
      ")"
  end

  def self.default_order
    "name"
  end
end
