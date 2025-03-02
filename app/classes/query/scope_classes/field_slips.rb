# frozen_string_literal: true

class Query::ScopeClasses::FieldSlips < Query::BaseAR
  def model
    FieldSlip
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      by_users: [User],
      projects: [Project]
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    initialize_projects_parameter(:field_slips, nil)
    super
  end

  def self.default_order
    :code_then_date
  end
end
