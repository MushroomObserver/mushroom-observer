# frozen_string_literal: true

# base class for Query's which return Names
class Query::Names < Query::BaseAR
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  # include Query::Initializers::AdvancedSearch
  # include Query::Initializers::Filters

  def model
    @model ||= Name
  end

  def alphabetical_by
    @alphabetical_by ||= Name[:sort_name]
  end

  def self.parameter_declarations # rubocop:disable Metrics/MethodLength
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Name],
      by_users: [User],
      by_editor: User,
      names: { lookup: [Name],
               include_synonyms: :boolean,
               include_subtaxa: :boolean,
               include_immediate_subtaxa: :boolean,
               exclude_original_names: :boolean },
      text_name_has: :string,
      # clade: :string, # content_filter
      # lichen: :boolean, # content_filter
      misspellings: { string: [:no, :either, :only] },
      deprecated: :boolean,
      has_synonyms: :boolean,
      ok_for_export: :boolean,
      has_author: :boolean,
      author_has: :string,
      has_citation: :boolean,
      citation_has: :string,
      has_classification: :boolean,
      classification_has: :string,
      has_notes: :boolean,
      notes_has: :string,
      rank: [{ string: Name.all_ranks }],
      has_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string,
      locations: [Location],
      species_lists: [SpeciesList],
      needs_description: :boolean,
      has_descriptions: :boolean,
      has_default_description: :boolean,
      has_observations: { boolean: [true] },
      description_query: { subquery: :NameDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Name)).
      merge(advanced_search_parameter_declarations)
  end

  def self.default_order
    :name
  end
end
