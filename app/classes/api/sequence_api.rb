class API
  # API for nucleotide sequences
  class SequenceAPI < ModelAPI
    self.model = Sequence

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :observation,
      :user
    ]

    self.low_detail_includes = [
    ]

    def query_params
      {
        # These apply to sequence itself:
        where:          sql_id_condition,
        created_at:     parse_time_range(:created_at),
        updated_at:     parse_time_range(:updated_at),
        users:          parse_users(:user),
        locus_has:      parse_string(:locus),
        archive_has:    parse_string(:archive),
        accession_has:  parse_string(:accession),
        notes_has:      parse_string(:notes)
        # These apply to parent observation:
        date:           parse_date_range(:date),
        observers:      parse_users(:observer),
        names:          parse_strings(:name),
        synonym_names:  parse_strings(:synonyms_of),
        children_names: parse_strings(:children_of),
        locations:      parse_strings(:locations),
        projects:       parse_strings(:projects),
        species_lists:  parse_strings(:species_lists),
        confidence:     parse_float_range(
          :confidence,
          limit: Range.new(Vote.minimum_vote, Vote.maximum_vote)
        ),
        north:          parse_latitude(:north),
        south:          parse_latitude(:south),
        east:           parse_longitude(:east),
        west:           parse_longitude(:west)
      }
    end

    def create_params
      {
        observation:  parse_observation(:observation,
                                        must_have_edit_permission: true),
        user:         @user,
        locus:        parse_string(:locus, default: ""),
        bases:        parse_string(:bases, default: ""),
        archive:      parse_string(:archive, default: ""),
        accession:    parse_string(:accession, default: ""),
        notes:        parse_string(:notes, default: "")
      }
    end

    def update_params
      {
        locus:      :locus,
        bases:      :bases,
        archive:    :archive,
        accession:  :accession,
        notes:      :notes
      }
    end

    def validate_create_params!(params); end
  end
end
