# frozen_string_literal: true

module Query::Initializers::Names
  def initialize_names_and_related_names_parameters(*joins)
    return force_empty_results if irreconcilable_names_parameters?

    table = params[:include_all_name_proposals] ? "namings" : "observations"
    ids = lookup_names_by_name(params[:names], related_names_parameters)
    add_association_condition("#{table}.name_id", ids, *joins)

    add_join(:observations, :namings) if params[:include_all_name_proposals]
    return unless params[:exclude_consensus]

    add_not_associated_condition("observations.name_id", ids, *joins)
  end

  # ------------------------------------------------------------------------

  NAMES_EXPANDER_PARAMS = [
    :include_synonyms, :include_subtaxa, :include_immediate_subtaxa,
    :exclude_original_names
  ].freeze

  private

  def related_names_parameters
    params.dup.slice(*NAMES_EXPANDER_PARAMS).compact
  end

  def irreconcilable_names_parameters?
    params[:exclude_consensus] && !params[:include_all_name_proposals]
  end
end
