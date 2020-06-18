# frozen_string_literal: true

class Query::LocationDescriptionBase < Query::Base
  def model
    Location::Description
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User]
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("location_descriptions")
    super
  end

  def default_order
    "name"
  end
end
