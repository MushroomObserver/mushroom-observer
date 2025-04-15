# frozen_string_literal: true

class Query::GlossaryTerms < Query::Base
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:by_users, [User])
  query_attr(:name_has, :string)
  query_attr(:description_has, :string)
  query_attr(:pattern, :string)

  def alphabetical_by
    @alphabetical_by ||= GlossaryTerm[:name]
  end

  def self.default_order
    :name
  end
end
