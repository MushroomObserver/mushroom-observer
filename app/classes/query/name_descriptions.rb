# frozen_string_literal: true

class Query::NameDescriptions < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [NameDescription])
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  # param_alias: matches its own attr name here -- not a rename, just
  # opts these into create_query_from_url_params's record-lookup path
  # (flash + redirect on a bad id), the same as any other aliased attr.
  # always_index: false -- a single matching description auto-redirects
  # straight to it rather than showing a one-row index (tested,
  # deliberate: see test_index_by_author_of_one_description).
  query_attr(:by_author, User, param_alias: :by_author, always_index: false)
  query_attr(:by_editor, User, param_alias: :by_editor, always_index: false)
  query_attr(:is_public, :boolean)
  query_attr(:sources, [{ string: ::Description::ALL_SOURCE_TYPES }])
  query_attr(:projects, [Project], param_alias: :project)
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
