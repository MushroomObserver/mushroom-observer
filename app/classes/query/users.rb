# frozen_string_literal: true

class Query::Users < Query::Base
  def model
    @model ||= User
  end

  def list_by
    @list_by ||= case params[:order_by]
                 when "login", "reverse_login"
                   User[:login]
                 else
                   User[:name]
                 end
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [User],
      has_contribution: :boolean,
      pattern: :string
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def initialize_flavor
    add_time_condition("users.created_at", params[:created_at])
    add_time_condition("users.updated_at", params[:updated_at])
    add_id_in_set_condition
    add_pattern_condition
    add_contribution_condition
    super
  end

  def add_contribution_condition
    return unless params[:has_contribution].to_s == "true"

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
