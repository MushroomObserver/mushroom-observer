# frozen_string_literal: true

class Query::FieldSlips < Query::Base
  def model
    @model ||= FieldSlip
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      by_users: [User],
      projects: [Project]
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions
    initialize_projects_parameter(:field_slips, nil)
    super
  end

  def self.default_order
    "code_then_date"
  end
end
