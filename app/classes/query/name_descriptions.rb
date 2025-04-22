# frozen_string_literal: true

class Query::NameDescriptions < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [NameDescription])
  query_attr(:by_users, [User])
  query_attr(:by_author, User)
  query_attr(:by_editor, User)
  query_attr(:is_public, :boolean)
  query_attr(:sources, [{ string: Description::ALL_SOURCE_TYPES }])
  query_attr(:projects, [Project])
  query_attr(:ok_for_export, :boolean)
  query_attr(:content_has, :string)
  query_attr(:names, { lookup: [Name],
                       include_synonyms: :boolean,
                       include_subtaxa: :boolean,
                       include_immediate_subtaxa: :boolean,
                       exclude_original_names: :boolean })
  query_attr(:name_query, { subquery: :Name })

  def self.default_order
    :name
  end
end
