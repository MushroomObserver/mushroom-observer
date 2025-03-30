# frozen_string_literal: true

class Query::Comments < Query::BaseAM
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Comment],
      by_users: [User],
      for_user: User,
      target: { type: :string, id: AbstractModel },
      types: [{ string: Comment::ALL_TYPE_TAGS }],
      summary_has: :string,
      content_has: :string,
      pattern: :string
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Comment
  end

  def alphabetical_by
    @alphabetical_by ||= User[:login]
  end

  def self.default_order
    :created_at
  end
end
