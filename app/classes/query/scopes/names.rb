# frozen_string_literal: true

module Query::Scopes::Names
  def initialize_name_comments_and_notes_parameters
    initialize_name_notes_parameters
    initialize_name_comments_parameters
  end

  def initialize_name_notes_parameters
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.notes,'')) > 0",
    #   "LENGTH(COALESCE(names.notes,'')) = 0",
    #   params[:with_notes]
    # )
    add_presence_condition(Name[:notes], params[:with_notes])
    add_search_condition(
      # "names.notes",
      Name[:notes],
      params[:notes_has]
    )
  end

  def initialize_name_comments_parameters
    # add_join(:comments) if params[:with_comments]
    @scopes = @scopes.joins(:comments) if params[:with_comments]
    add_search_condition(
      # "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      Comment[:summary] + Comment[:comment].coalesce(""),
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
    # where << "names.correct_spelling_id IS NULL"     if val == :no
    # where << "names.correct_spelling_id IS NOT NULL" if val == :only
    @scopes = @scopes.with_correct_spelling if val == :no
    @scopes = @scopes.with_incorrect_spelling if val == :only
  end

  # Not sure how these two are different!
  def initialize_deprecated_parameter
    val = params[:deprecated] || :either
    # where << "names.deprecated IS FALSE" if val == :no
    # where << "names.deprecated IS TRUE"  if val == :only
    @scopes = @scopes.not_deprecated if val == :no
    @scopes = @scopes.deprecated if val == :only
  end

  def add_rank_condition(vals, joins)
    return if vals.to_s.empty?

    min, max = vals
    # max ||= min
    # all_ranks = Name.all_ranks
    # a = all_ranks.index(min) || 0
    # b = all_ranks.index(max) || (all_ranks.length - 1)
    # a, b = b, a if a > b
    # ranks = all_ranks[a..b].map { |r| Name.ranks[r] }
    # @where << "names.`rank` IN (#{ranks.join(",")})"
    @scopes = @scopes.with_rank_between(min, max)
    @scopes = @scopes.joins(joins) if joins
  end

  def initialize_is_deprecated_parameter
    # "names.deprecated IS TRUE", "names.deprecated IS FALSE",
    add_boolean_column_condition(Name[:deprecated], params[:is_deprecated])
  end

  def initialize_name_association_parameters
    add_id_condition(Observation[:id], params[:observations], :observations)
    add_observation_location_condition(
      Observation, params[:locations], :observations
    )
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
      # "names.synonym_id IS NOT NULL", "names.synonym_id IS NULL",
      Name[:synonym_id].not_eq(nil), Name[:synonym_id].eq(nil),
      params[:with_synonyms]
    )
  end

  def initialize_with_author_parameter
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.author,'')) > 0",
    #   "LENGTH(COALESCE(names.author,'')) = 0",
    #   params[:with_author]
    # )
    add_presence_condition(Name[:author], params[:with_author])
  end

  def initialize_with_citation_parameter
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.citation,'')) > 0",
    #   "LENGTH(COALESCE(names.citation,'')) = 0",
    #   params[:with_citation]
    # )
    add_presence_condition(Name[:citation], params[:with_citation])
  end

  def initialize_with_classification_parameter
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.classification,'')) > 0",
    #   "LENGTH(COALESCE(names.classification,'')) = 0",
    #   params[:with_classification]
    # )
    add_presence_condition(Name[:classification], params[:with_classification])
  end

  def initialize_name_search_parameters
    add_search_condition(Name[:text_name], params[:text_name_has])
    add_search_condition(Name[:author], params[:author_has])
    add_search_condition(Name[:citation], params[:citation_has])
    add_search_condition(Name[:classification], params[:classification_has])
  end

  def add_name_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    # add_join(:observations) if params[:content].present?
    @scopes = @scopes.joins(:observations) if params[:content].present?
    initialize_advanced_search
  end

  def initialize_name_parameters(joins)
    return force_empty_results if irreconcilable_name_parameters?

    table = params[:include_all_name_proposals] ? Naming : Observation
    table_column = table[:name_id]
    ids = lookup_names_by_name(names_parameters)
    add_id_condition(table_column, ids, joins)

    if params[:include_all_name_proposals]
      # add_join(:observations, :namings)
      @scopes = @scopes.joins(observations: :namings)
    end
    return unless params[:exclude_consensus]

    add_not_id_condition(Observation[:name_id], ids, joins)
  end

  def force_empty_results
    # @where = ["FALSE"]
    @scopes = @scopes.none
  end

  def initialize_name_parameters_for_name_queries
    # Much simpler form for non-observation-based name queries.
    add_id_condition(Name[:id], lookup_names_by_name(names_parameters))
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
