class Query::SequencePatternSearch < Query::SequenceBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    super
  end

  def search_fields
    # I'm leaving out bases because it would be misleading.  Some formats
    # allow spaces and other delimiting "garbage" which could break up
    # the subsequence the user is searching for.
    "CONCAT(" \
      "COALESCE(sequences.locus,'')," \
      "COALESCE(sequences.archive,'')," \
      "COALESCE(sequences.accession,'')," \
      "COALESCE(sequences.notes,'')" \
      ")"
  end
end
