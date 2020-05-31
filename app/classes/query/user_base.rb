# frozen_string_literal: true

class Query::UserBase < Query::Base
  def model
    User
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time]
    )
  end

  def initialize_flavor
    add_time_condition("users.created_at", params[:created_at])
    add_time_condition("users.updated_at", params[:updated_at])
    super
  end

  def default_order
    "name"
  end
end
