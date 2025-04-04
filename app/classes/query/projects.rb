# frozen_string_literal: true

class Query::Projects < Query::BaseNew
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Project],
      by_users: [User],
      members: [User],
      title_has: :string,
      has_summary: :boolean,
      summary_has: :string,
      field_slip_prefix_has: :string,
      has_images: { boolean: [true] },
      has_observations: { boolean: [true] },
      has_species_lists: { boolean: [true] },
      has_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Project
  end

  def alphabetical_by
    @alphabetical_by ||= Project[:title]
  end

  def self.default_order
    :updated_at
  end
end
