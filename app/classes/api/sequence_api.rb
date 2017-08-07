class API
  # API for nucleotide sequences
  class SequenceAPI < ModelAPI
    self.model = Sequence

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    def query_params
      {
        where:         sql_id_condition,
        created_at:    parse_time_range(:created_at),
        updated_at:    parse_time_range(:updated_at),
        users:         parse_users(:user),
        locus_has:     parse_strings(:locus),
        bases_has:     parse_strings(:bases),
        accession_has: parse_strings(:accession)
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
