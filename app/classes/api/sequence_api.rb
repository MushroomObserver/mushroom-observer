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

    # rubocop:disable Metrics/AbcSize
    def query_params
      {
        where:          sql_id_condition,
        created_at:     parse_range(:time, :created_at),
        updated_at:     parse_range(:time, :updated_at),
        users:          parse_array(:user, :user),
        locus_has:      parse(:string, :locus),
        archive_has:    parse(:string, :archive),
        accession_has:  parse(:string, :accession),
        notes_has:      parse(:string, :notes),
        date:           parse_range(:date, :date),
        observers:      parse_array(:user, :observer),
        names:          parse_array(:name, :name, as: :id),
        synonym_names:  parse_array(:name, :synonyms_of, as: :id),
        children_names: parse_array(:name, :children_of, as: :id),
        locations:      parse_array(:location, :location, as: :id),
        projects:       parse_array(:project, :project, as: :id),
        species_lists:  parse_array(:species_list, :species_list, as: :id),
        confidence:     parse(:confidence, :confidence),
        north:          parse(:latitude, :north),
        south:          parse(:latitude, :south),
        east:           parse(:longitude, :east),
        west:           parse(:longitude, :west)
      }
    end
    # rubocop:enable Metrics/AbcSize

    def create_params
      {
        observation: parse_observation_to_attach_to,
        user:        @user,
        locus:       parse(:string, :locus),
        bases:       parse(:string, :bases),
        archive:     parse(:string, :archive, limit: 255),
        accession:   parse(:string, :accession, limit: 255),
        notes:       parse(:string, :notes)
      }
    end

    def update_params
      {
        locus:     parse(:string, :set_locus),
        bases:     parse(:string, :set_bases),
        archive:   parse(:string, :set_archive, limit: 255),
        accession: parse(:string, :set_accession, limit: 255),
        notes:     parse(:string, :set_notes)
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:observation) unless params[:observation]
      raise MissingParameter.new(:locus)       if params[:locus].blank?
      # Sequence validators handle the rest, it's too complicated to repeat.
    end

    ############################################################################

    private

    def parse_observation_to_attach_to
      parse(:observation, :observation, must_have_edit_permission: true)
    end
  end
end
