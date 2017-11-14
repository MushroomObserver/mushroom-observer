class API
  # API for Image
  class ImageAPI < ModelAPI
    self.model = Image

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :user
    ]

    # rubocop:disable Metrics/AbcSize
    def query_params
      {
        where:                sql_id_condition,
        created_at:           parse_range(:time, :created_at),
        updated_at:           parse_range(:time, :updated_at),
        date:                 parse_range(:date, :date),
        users:                parse_array(:user, :user),
        names:                parse_array(:string, :name),
        synonym_names:        parse_array(:string, :synonyms_of),
        children_names:       parse_array(:string, :children_of),
        locations:            parse_array(:string, :location),
        projects:             parse_array(:string, :projects),
        species_lists:        parse_array(:string, :species_lists),
        has_observation:      parse(:boolean, :has_observation, limit: true),
        size:                 parse(:size, :has_size),
        content_types:        parse(:string, :content_type),
        has_notes:            parse(:boolean, :has_notes),
        notes_has:            parse(:string, :notes_has),
        copyright_holder_has: parse(:string, :copyright_holder_has),
        license:              parse(:license, :license),
        has_votes:            parse(:boolean, :has_votes),
        quality:              parse(:quality, :quality),
        confidence:           parse(:confidence, :confidence),
        ok_for_export:        parse(:boolean, :ok_for_export)
      }
    end
    # rubocop:enable Metrics/AbcSize

    def build_object
      params = create_params
      vote = parse(:enum, :vote, limit: Image.all_votes)
      upload = prepare_upload
      params.merge!(upload_params(upload)) if upload
      done_parsing_parameters!
      raise MissingUpload.new unless upload
      img = create_image(params)
      change_vote(img, vote)
      img
    ensure
      upload.clean_up if upload
    end

    def create_params
      observations = parse_observations_to_attach_to
      default_date = observations.any? ? observations.first.when : Date.today
      {
        when:             parse(:date, :date, default: default_date),
        notes:            parse(:string, :notes, default: ""),
        copyright_holder: parse_copyright_holder,
        license:          parse(:license, :license, default: user.license),
        original_name:    parse_original_name,
        projects:         parse_projects_to_attach_to,
        observations:     observations
      }
    end

    def update_params
      {
        when:             parse(:date, :set_date),
        notes:            parse(:string, :set_notes),
        copyright_holder: parse(:string, :set_copyright_holder, limit: 100),
        license:          parse(:license, :set_license),
        original_name:    parse(:string, :set_original, limit: 120)
      }
    end

    ############################################################################

    private

    def create_image(params)
      img = model.new(params)
      img.save          || raise(CreateFailed.new(img))
      img.process_image || raise(ImageUploadFailed.new(img))
      params[:observations].each do |obs|
        obs.update(thumb_image_id: img.id) unless obs.thumb_image_id
        obs.log_create_image(img)
      end
      img
    end

    def change_vote(img, vote)
      return unless vote
      img.change_vote(@user, vote, (@user.votes_anonymous == :yes))
    end

    def upload_params(upload)
      {
        image:          upload.content,
        upload_length:  upload.content_length,
        upload_type:    upload.content_type,
        upload_md5sum:  upload.content_md5
      }
    end

    def parse_copyright_holder
      parse(:string, :copyright_holder, limit: 100, default: user.legal_name)
    end

    def parse_original_name
      parse(:string, :original_name, limit: 120, default: nil)
    end

    def parse_observations_to_attach_to
      parse_array(:observation, :observations,
                  must_have_edit_permission: true) || []
    end

    def parse_projects_to_attach_to
      parse_array(:project, :projects, must_be_member: true) || []
    end
  end
end
