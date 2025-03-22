# frozen_string_literal: true

class Query::Users < Query::BaseAR
  def model
    @model ||= User
  end

  def list_by
    @list_by ||= case params[:by]
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

  def self.default_order
    "name"
  end

  # def initialize_flavor
  #   add_time_condition("users.created_at", params[:created_at])
  #   add_time_condition("users.updated_at", params[:updated_at])
  #   add_id_in_set_condition
  #   add_pattern_condition
  #   add_contribution_condition
  #   super
  # end

  # def add_contribution_condition
  #   return unless params[:has_contribution].to_s == "true"

  #   where << "users.contribution > 0"
  # end

  # def search_fields
  #   "CONCAT(" \
  #     "users.login," \
  #     "users.name" \
  #     ")"
  # end
end
