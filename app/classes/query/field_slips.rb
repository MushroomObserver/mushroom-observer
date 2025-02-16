# frozen_string_literal: true

class Query::FieldSlips < Query::Base
  def model
    FieldSlip
  end

  def parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      by_user: User,
      project: Project
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_for_project_condition
    super
  end

  def self.default_order
    "code_then_date"
  end
end
