# frozen_string_literal: true

module Query::Initializers::Names
  def initialize_name_parameters(*joins)
    return force_empty_results if irreconcilable_name_parameters?

    table = params[:include_all_name_proposals] ? "namings" : "observations"
    column = "#{table}.name_id"
    ids = lookup_names_by_name(params[:names], names_parameters)
    add_id_condition(column, ids, *joins)

    add_join(:observations, :namings) if params[:include_all_name_proposals]
    return unless params[:exclude_consensus]

    column = "observations.name_id"
    add_not_id_condition(column, ids, *joins)
  end

  # Much simpler form for non-observation-based name queries.
  def initialize_name_parameters_for_name_queries
    ids = lookup_names_by_name(params[:names], names_parameters)
    add_id_condition("names.id", ids)
  end

  # ------------------------------------------------------------------------

  NAMES_EXPANDER_PARAMS = [
    :include_synonyms, :include_subtaxa, :include_immediate_subtaxa,
    :exclude_original_names
  ].freeze

  private

  def names_parameters
    params.dup.slice(*NAMES_EXPANDER_PARAMS).compact
  end

  def irreconcilable_name_parameters?
    params[:exclude_consensus] && !params[:include_all_name_proposals]
  end
end
