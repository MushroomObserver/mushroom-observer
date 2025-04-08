# frozen_string_literal: true

class Query::Images < Query::Base
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      date: [:date],
      id_in_set: [Image],
      by_users: [User],
      sizes: [{ string: Image::ALL_SIZES - [:full_size] }],
      content_types: [{ string: Image::ALL_EXTENSIONS }],
      has_notes: :boolean,
      notes_has: :string,
      copyright_holder_has: :string,
      license: [License],
      ok_for_export: :boolean,
      has_votes: :boolean,
      quality: [:float],
      confidence: [:float],
      pattern: :string,
      has_observations: :boolean,
      observations: [Observation],
      locations: [Location],
      projects: [Project],
      species_lists: [SpeciesList],
      observation_query: { subquery: :Observation }
    )
  end

  # Declare the parameters as model attributes, of custom type `query_param`

  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Image
  end

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by].to_s
                         when "user", "reverse_user"
                           User[:login]
                         when "name", "reverse_name"
                           Name[:sort_name]
                         end
  end

  def self.default_order
    "created_at"
  end
end
