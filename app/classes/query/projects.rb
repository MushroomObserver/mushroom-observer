# frozen_string_literal: true

class Query::Projects < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Project])
  query_attr(:by_users, [User])
  query_attr(:members, [User])
  query_attr(:names, [Name])
  query_attr(:title_has, :string)
  query_attr(:has_summary, :boolean)
  query_attr(:summary_has, :string)
  query_attr(:field_slip_prefix_has, :string)
  query_attr(:has_images, { boolean: [true] })
  query_attr(:has_observations, { boolean: [true] })
  query_attr(:has_species_lists, { boolean: [true] })
  query_attr(:has_comments, { boolean: [true] })
  query_attr(:comments_has, :string)
  query_attr(:pattern, :string)

  def alphabetical_by
    @alphabetical_by ||= Project[:title]
  end

  def self.default_order
    :updated_at
  end
end
