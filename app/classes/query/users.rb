# frozen_string_literal: true

class Query::Users < Query::Base
  def model
    User
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [User],
      id_range: [:integer],
      pattern: :string,
      with_contribution: :boolean
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_time_condition("users.created_at", params[:created_at])
    add_time_condition("users.updated_at", params[:updated_at])
    add_ids_condition
    add_pattern_condition
    add_contribution_condition
    super
  end

  def add_contribution_condition
    return unless params[:with_contribution].to_s == "true"

    @title_tag = :query_title_with_contribution
    where << "users.contribution > 0"
  end

  def search_fields
    "CONCAT(" \
      "users.login," \
      "users.name" \
      ")"
  end

  def self.default_order
    "name"
  end
end
