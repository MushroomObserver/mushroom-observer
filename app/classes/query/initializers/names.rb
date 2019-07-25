# frozen_string_literal: true

module Query
  module Initializers
    # initializing methods inherited by all Query's for Names
    module Names
      def names_parameter_declarations
        {
          names?: [:string],
          include_synonyms?: :boolean,
          include_subtaxa?: :boolean,
          include_immediate_subtaxa?: :boolean,
          exclude_original_names?: :boolean
        }
      end

      def consensus_parameter_declarations
        {
          include_all_name_proposals?: :boolean,
          exclude_consensus?: :boolean
        }
      end

      def names_parameters
        {
          names: params[:names],
          include_synonyms: params[:include_synonyms],
          include_subtaxa: params[:include_subtaxa],
          include_immediate_subtaxa: params[:include_immediate_subtaxa],
          exclude_original_names: params[:exclude_original_names]
        }
      end

      def initialize_name_parameters(*joins)
        return add_false_condition if irreconcilable_name_parameters?

        table = if params[:include_all_name_proposals]
                  "namings"
                else
                  "observations"
                end
        column = "#{table}.name_id"
        ids = lookup_names_by_name(names_parameters)
        add_id_condition(column, ids,*joins)

        add_join(:observations, :namings) if params[:include_all_name_proposals]
        return unless params[:exclude_consensus]

        column = "observations.name_id"
        add_not_id_condition(column, ids, *joins)
      end

      def initialize_name_parameters_for_name_queries
        # Much simpler form for non-observation-based name queries.
        add_id_condition("names.id", lookup_names_by_name(names_parameters))
      end

      # ------------------------------------------------------------------------

      private

      def irreconcilable_name_parameters?
        params[:exclude_consensus] && !params[:include_all_name_proposals]
      end
    end
  end
end
