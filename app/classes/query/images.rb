# frozen_string_literal: true

class Query::Images < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:date, [:date])
  query_attr(:id_in_set, [Image])
  query_attr(:by_users, [User])
  query_attr(:sizes, [{ string: Image::ALL_SIZES - [:full_size] }])
  query_attr(:content_types, [{ string: Image::ALL_EXTENSIONS }])
  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:copyright_holder_has, :string)
  query_attr(:license, [License])
  query_attr(:ok_for_export, :boolean)
  query_attr(:has_votes, :boolean)
  query_attr(:quality, [:float])
  query_attr(:confidence, [:float])
  query_attr(:pattern, :string)
  query_attr(:has_observations, :boolean)
  query_attr(:observations, [Observation])
  query_attr(:locations, [Location])
  query_attr(:projects, [Project])
  query_attr(:species_lists, [SpeciesList])
  query_attr(:observation_query, { subquery: :Observation })

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
