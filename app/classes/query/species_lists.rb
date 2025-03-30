# frozen_string_literal: true

class Query::SpeciesLists < Query::BaseNew
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      date: [:date],
      id_in_set: [SpeciesList],
      by_users: [User],
      title_has: :string,
      has_notes: :boolean,
      notes_has: :string,
      has_comments: { boolean: [true] },
      comments_has: :string,
      search_where: :string,
      locations: [Location],
      projects: [Project],
      pattern: :string,
      observation_query: { subquery: :Observation }
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= SpeciesList
  end

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by].to_s
                         when "user", "reverse_user"
                           User[:login]
                         else
                           SpeciesList[:title]
                         end
  end

  def self.default_order
    :title
  end
end
