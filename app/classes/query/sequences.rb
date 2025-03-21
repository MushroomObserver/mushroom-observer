# frozen_string_literal: true

class Query::Sequences < Query::BaseAR
  def model
    @model ||= Sequence
  end

  def list_by
    @list_by ||= Sequence[:locus]
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Sequence],
      by_users: [User],
      observations: [Observation],
      locus: [:string],
      locus_has: :string,
      archive: [:string],
      accession: [:string],
      accession_has: :string,
      notes_has: :string,
      pattern: :string,
      observation_query: { subquery: :Observation, joins: :observation }
    )
  end

  def self.default_order
    "created_at"
  end

  # def initialize_flavor
  #   # Leaving out bases because some formats allow spaces and other "garbage"
  #   # delimiters which could interrupt the subsequence the user is searching
  #   # for.  Users would probably not understand why the search fails to find
  #   # some sequences because of this.
  #   add_owner_and_time_stamp_conditions
  #   add_pattern_condition
  #   add_id_in_set_condition
  #   initialize_observations_parameter(:sequences)
  #   add_subquery_condition(:observation_query, :observations)
  #   initialize_exact_match_parameters
  #   initialize_search_parameters
  #   super
  # end

  # def search_fields
  #   # I'm leaving out bases because it would be misleading.  Some formats
  #   # allow spaces and other delimiting "garbage" which could break up
  #   # the subsequence the user is searching for.
  #   "CONCAT(" \
  #     "COALESCE(sequences.locus,'')," \
  #     "COALESCE(sequences.archive,'')," \
  #     "COALESCE(sequences.accession,'')," \
  #     "COALESCE(sequences.notes,'')" \
  #     ")"
  # end

  # def initialize_exact_match_parameters
  #   add_exact_match_condition("sequences.locus", params[:locus])
  #   add_exact_match_condition("sequences.archive", params[:archive])
  #   add_exact_match_condition("sequences.accession", params[:accession])
  # end

  # def initialize_search_parameters
  #   add_search_condition("sequences.locus", params[:locus_has])
  #   add_search_condition("sequences.accession", params[:accession_has])
  #   add_search_condition("sequences.notes", params[:notes_has])
  #   add_search_condition("observations.notes", params[:obs_notes_has],
  #                        :observations)
  # end
end
