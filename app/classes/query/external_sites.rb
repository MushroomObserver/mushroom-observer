# frozen_string_literal: true

class Query::ExternalSites < Query::BaseAR
  def model
    @model ||= ExternalSite
  end

  def self.parameter_declarations
    super.merge(
      id_in_set: [ExternalSite],
      name_has: :string
    )
  end

  def self.default_order
    :name
  end
end
