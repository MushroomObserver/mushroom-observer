# frozen_string_literal: true

module Query::Initializers::Names
  def initialize_names_and_related_names_parameters(*joins)
    return force_empty_results if irreconcilable_names_parameters?

    table = if params.dig(:names, :include_all_name_proposals)
              "namings"
            else
              "observations"
            end
    ids = lookup_names_by_name(params.dig(:names, :lookup),
                               related_names_parameters)
    add_association_condition("#{table}.name_id", ids, *joins)

    if params.dig(:names, :include_all_name_proposals)
      add_join(:observations, :namings)
    end
    return unless params.dig(:names, :exclude_consensus)

    add_not_associated_condition("observations.name_id", ids, *joins)
  end

  # ------------------------------------------------------------------------

  NAMES_EXPANDER_PARAMS = [
    :include_synonyms, :include_subtaxa, :include_immediate_subtaxa,
    :exclude_original_names
  ].freeze

  private

  def related_names_parameters
    params[:names].dup.slice(*NAMES_EXPANDER_PARAMS).compact
  end

  def irreconcilable_names_parameters?
    params.dig(:names, :exclude_consensus) &&
      !params.dig(:names, :include_all_name_proposals)
  end
end
