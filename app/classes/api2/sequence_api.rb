# frozen_string_literal: true

class API2
  # API2 for Sequence
  class SequenceAPI2 < ModelAPI2
    self.model = Sequence

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :user
    ]

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def query_params
      n, s, e, w = parse_bounding_box!
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users: parse_array(:user, :user, help: :creator),
        locus: parse_array(:string, :locus),
        archive: parse_array(:archive, :archive),
        accession: parse_array(:string, :accession),
        locus_has: parse(:string, :locus_has, help: 1),
        accession_has: parse(:string, :accession_has, help: 1),
        notes_has: parse(:string, :notes_has, help: 1),
        obs_date: parse_range(:date, :obs_date, help: :obs_date),
        observers: parse_array(:user, :observer),
        names: parse_array(:name, :name, as: :id),
        locations: parse_array(:location, :location, as: :id),
        herbaria: parse_array(:herbarium, :herbarium, as: :id),
        herbarium_records: parse_array(:herbarium_record, :herbarium_record,
                                       as: :id),
        projects: parse_array(:project, :project, as: :id),
        species_lists: parse_array(:species_list, :species_list, as: :id),
        confidence: parse(:confidence, :confidence),
        north: n,
        south: s,
        east: e,
        west: w,
        is_collection_location: parse(:boolean, :is_collection_location,
                                      help: 1),
        has_images: parse(:boolean, :has_images),
        has_name: parse(:boolean, :has_name, help: :min_rank),
        has_specimen: parse(:boolean, :has_specimen),
        has_obs_notes: parse(:boolean, :has_obs_notes, help: 1),
        has_notes_fields: parse(:string, :has_notes_field, help: 1),
        obs_notes_has: parse(:string, :obs_notes_has, help: 1)
      }.merge(parse_names_parameters)
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def create_params
      {
        observation: parse(:observation, :observation),
        locus: parse(:string, :locus),
        bases: parse(:string, :bases),
        archive: parse(:archive, :archive),
        accession: parse(:string, :accession, limit: 255),
        notes: parse(:string, :notes),
        user: @user
      }
    end

    def update_params
      {
        locus: parse(:string, :set_locus, not_blank: true),
        bases: parse(:string, :set_bases),
        archive: parse(:archive, :set_archive),
        accession: parse(:string, :set_accession, limit: 255),
        notes: parse(:string, :set_notes)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:observation)) unless params[:observation]
      raise(MissingParameter.new(:locus))       if params[:locus].blank?
      # Sequence validators handle the rest, it's too complicated to repeat.
    end
  end
end
