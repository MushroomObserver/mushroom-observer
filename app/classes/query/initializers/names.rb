# frozen_string_literal: true

module Query::Initializers::Names
  def names_per_se_parameter_declarations
    {
      created_at?: [:time],
      updated_at?: [:time],
      ids?: [Name],
      by_user?: User,
      by_editor?: User,
      users?: [User],
      misspellings?: { string: [:no, :either, :only] },
      deprecated?: { string: [:either, :no, :only] },
      with_synonyms?: :boolean,
      locations?: [:string],
      species_lists?: [:string],
      rank?: [{ string: Name.all_ranks }],
      is_deprecated?: :boolean,
      pattern?: :string,
      text_name_has?: :string,
      with_author?: :boolean,
      author_has?: :string,
      with_citation?: :boolean,
      citation_has?: :string,
      with_classification?: :boolean,
      classification_has?: :string,
      with_notes?: :boolean,
      notes_has?: :string,
      with_comments?: { boolean: [true] },
      comments_has?: :string,
      need_description?: :boolean,
      with_descriptions?: :boolean,
      with_observations?: { boolean: [true] }
    }
  end

  # Used in coerced queries for obs, plus sequence and species_list queries
  def names_parameter_declarations
    {
      names?: [:string],
      include_synonyms?: :boolean,
      include_subtaxa?: :boolean,
      include_immediate_subtaxa?: :boolean,
      exclude_original_names?: :boolean
    }
  end

  def naming_consensus_parameter_declarations
    {
      include_all_name_proposals?: :boolean,
      exclude_consensus?: :boolean
    }
  end

  def initialize_name_comments_and_notes_parameters
    add_boolean_condition(
      "LENGTH(COALESCE(names.notes,'')) > 0",
      "LENGTH(COALESCE(names.notes,'')) = 0",
      params[:with_notes]
    )
    add_join(:comments) if params[:with_comments]
    add_search_condition(
      "names.notes",
      params[:notes_has]
    )
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :comments
    )
  end

  def initialize_taxonomy_parameters
    initialize_misspellings_parameter
    initialize_deprecated_parameter
    add_rank_condition(params[:rank])
    initialize_is_deprecated_parameter
    initialize_ok_for_export_parameter
  end

  def initialize_misspellings_parameter
    val = params[:misspellings] || :no
    where << "names.correct_spelling_id IS NULL"     if val == :no
    where << "names.correct_spelling_id IS NOT NULL" if val == :only
  end

  # Not sure how these two are different!
  def initialize_deprecated_parameter
    val = params[:deprecated] || :either
    where << "names.deprecated IS FALSE" if val == :no
    where << "names.deprecated IS TRUE"  if val == :only
  end

  def initialize_is_deprecated_parameter
    add_boolean_condition(
      "names.deprecated IS TRUE", "names.deprecated IS FALSE",
      params[:is_deprecated]
    )
  end

  def initialize_ok_for_export_parameter
    add_boolean_condition(
      "names.ok_for_export IS TRUE", "names.ok_for_export IS FALSE",
      params[:ok_for_export]
    )
  end

  def initialize_name_association_parameters
    add_id_condition("observations.id", params[:observations], :observations)
    add_where_condition("observations", params[:locations], :observations)
    initialize_species_lists_parameter
  end

  def initialize_name_record_parameters
    initialize_with_synonyms_parameter
    initialize_with_author_parameter
    initialize_with_citation_parameter
    initialize_with_classification_parameter
    add_join(:observations) if params[:with_observations]
  end

  def initialize_with_synonyms_parameter
    add_boolean_condition(
      "names.synonym_id IS NOT NULL", "names.synonym_id IS NULL",
      params[:with_synonyms]
    )
  end

  def initialize_with_author_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(names.author,'')) > 0",
      "LENGTH(COALESCE(names.author,'')) = 0",
      params[:with_author]
    )
  end

  def initialize_with_citation_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(names.citation,'')) > 0",
      "LENGTH(COALESCE(names.citation,'')) = 0",
      params[:with_citation]
    )
  end

  def initialize_with_classification_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(names.classification,'')) > 0",
      "LENGTH(COALESCE(names.classification,'')) = 0",
      params[:with_classification]
    )
  end

  def initialize_name_search_parameters
    add_search_condition("names.text_name", params[:text_name_has])
    add_search_condition("names.author", params[:author_has])
    add_search_condition("names.citation", params[:citation_has])
    add_search_condition("names.classification", params[:classification_has])
  end

  def add_name_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    add_join(:observations) if params[:content].present?
    initialize_advanced_search
  end

  def initialize_name_parameters(*joins)
    return force_empty_results if irreconcilable_name_parameters?

    table = params[:include_all_name_proposals] ? "namings" : "observations"
    column = "#{table}.name_id"
    ids = lookup_names_by_name(names_parameters)
    add_id_condition(column, ids, *joins)

    add_join(:observations, :namings) if params[:include_all_name_proposals]
    return unless params[:exclude_consensus]

    column = "observations.name_id"
    add_not_id_condition(column, ids, *joins)
  end

  def initialize_name_parameters_for_name_queries
    # Much simpler form for non-observation-based name queries.
    add_id_condition("names.id", lookup_names_by_name(names_parameters))
  end

  # Copy only the names_parameters into a name_params hash we use here.
  def names_parameters
    name_params = names_parameter_declarations.dup
    name_params.transform_keys! { |k| k.to_s.chomp("?").to_sym }
    name_params.each_key { |k| name_params[k] = params[k] }
    name_params
  end

  # ------------------------------------------------------------------------

  private

  def irreconcilable_name_parameters?
    params[:exclude_consensus] && !params[:include_all_name_proposals]
  end
end
