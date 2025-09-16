# frozen_string_literal: true

class Query::SpeciesLists < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:date, [:date])
  query_attr(:id_in_set, [SpeciesList])
  query_attr(:by_users, [User])
  query_attr(:editable_by_user, User)
  query_attr(:title_has, :string)
  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:has_comments, { boolean: [true] })
  query_attr(:comments_has, :string)
  query_attr(:search_where, :string)
  query_attr(:region, :string) # accepts multiple values for :search_where
  query_attr(:pattern, :string)
  query_attr(:locations, [Location])
  query_attr(:names, [Name])
  query_attr(:projects, [Project])
  query_attr(:observation_query, { subquery: :Observation })

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by].to_s
                         when "user", "reverse_user"
                           User[:login]
                         else
                           SpeciesList[:title]
                         end
  end

  def self.default_order
    :date
  end
end
