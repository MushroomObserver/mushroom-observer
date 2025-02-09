# frozen_string_literal: true

module Query::Params::Names
  def names_per_se_parameter_declarations
    {
      created_at: [:time],
      updated_at: [:time],
      ids: [Name],
      by_user: User,
      by_editor: User,
      users: [User],
      locations: [Location],
      species_lists: [SpeciesList],
      misspellings: { string: [:no, :either, :only] },
      deprecated: { string: [:either, :no, :only] },
      is_deprecated: :boolean, # api param
      with_synonyms: :boolean,
      rank: [{ string: Name.all_ranks }],
      text_name_has: :string,
      with_author: :boolean,
      author_has: :string,
      with_citation: :boolean,
      citation_has: :string,
      with_classification: :boolean,
      classification_has: :string,
      with_notes: :boolean,
      notes_has: :string,
      with_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string,
      need_description: :boolean,
      with_descriptions: :boolean,
      with_observations: { boolean: [true] },
      descriptions_query: :query,
      observations_query: :query,
      rss_logs_query: :query,
      names: [Name],
      include_synonyms: :boolean,
      include_subtaxa: :boolean,
      include_immediate_subtaxa: :boolean,
      exclude_original_names: :boolean
      # include_all_name_proposals: :boolean,
      # exclude_consensus: :boolean
      # species_lists_query: :query
    }
  end

  # Used in coerced queries for obs, plus sequence and species_list queries
  # def names_parameter_declarations
  #   {
  #     names: [Name],
  #     include_synonyms: :boolean,
  #     include_subtaxa: :boolean,
  #     include_immediate_subtaxa: :boolean,
  #     exclude_original_names: :boolean
  #   }
  # end

  # def naming_consensus_parameter_declarations
  #   {
  #     include_all_name_proposals: :boolean,
  #     exclude_consensus: :boolean
  #   }
  # end
end
