# API
class API
  # API for Sequence
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

    def query_params
      sequence_query_params.merge(observation_query_params)
    end

    def sequence_query_params
      {
        where:         sql_id_condition,
        created_at:    parse_time_range(:created_at),
        updated_at:    parse_time_range(:updated_at),
        users:         parse_users(:user),
        locus_has:     parse_string(:locus),
        archive_has:   parse_string(:archive),
        accession_has: parse_string(:accession),
        notes_has:     parse_string(:notes)
      }
    end

    def observation_query_params
      {
        date:           parse_date_range(:date),
        observers:      parse_users(:observer),
        names:          parse_strings(:name),
        synonym_names:  parse_strings(:synonyms_of),
        children_names: parse_strings(:children_of),
        locations:      parse_strings(:locations),
        projects:       parse_strings(:projects),
        species_lists:  parse_strings(:species_lists),
        confidence:     parse_confidence,
        north:          parse_latitude(:north),
        south:          parse_latitude(:south),
        east:           parse_longitude(:east),
        west:           parse_longitude(:west)
      }
    end

    def create_params
      {
        observation: parse_observation_to_attach_to,
        user:        @user,
        locus:       parse_string(:locus),
        bases:       parse_string(:bases),
        archive:     parse_string(:archive, limit: 255),
        accession:   parse_string(:accession, limit: 255),
        notes:       parse_string(:notes)
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:observation) unless params[:observation]
      raise MissingParameter.new(:locus)       if params[:locus].blank?
      # Sequence validators handle the rest, it's too complicated to repeat.
    end

    def update_params
      {
        locus:     parse_string(:set_locus),
        bases:     parse_string(:set_bases),
        archive:   parse_string(:set_archive, limit: 255),
        accession: parse_string(:set_accession, limit: 255),
        notes:     parse_string(:set_notes)
      }
    end

    def parse_confidence
      limit = Range.new(Vote.minimum_vote, Vote.maximum_vote)
      parse_float_range(:confidence, limit: limit)
    end

    def parse_observation_to_attach_to
      parse_observation(:observation, must_have_edit_permission: true)
    end
  end
end
