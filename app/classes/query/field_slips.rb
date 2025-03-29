# frozen_string_literal: true

class Query::FieldSlips < Query::BaseAR
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

  def self.default_order
    :code_then_date
  end
end
