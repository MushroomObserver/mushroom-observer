# frozen_string_literal: true

module Query::ScopeInitializers::Names
  def initialize_name_parameters(joins)
    return force_empty_results if irreconcilable_name_parameters?

    table = params[:include_all_name_proposals] ? Naming : Observation
    table_column = table[:name_id]
    ids = lookup_names_by_name(names_parameters)
    add_association_condition(table_column, ids, joins)

    if params[:include_all_name_proposals]
      @scopes = @scopes.joins(observations: :namings)
    end
    return unless params[:exclude_consensus]

    add_not_associated_condition(Observation[:name_id], ids, joins)
  end

  # Much simpler form for non-observation-based name queries.
  def initialize_name_parameters_for_name_queries
    ids = lookup_names_by_name(params[:names], names_parameters)
    add_association_condition(Name[:id], ids)
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
