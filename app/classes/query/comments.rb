# frozen_string_literal: true

class Query::Comments < Query::BaseAR
  def model
    @model ||= Comment
  end

  def alphabetical_by
    @alphabetical_by ||= User[:login]
  end

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

  def self.default_order
    :created_at
  end
end
