# API
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
        created_at:           parse_time_range(:created_at),
        updated_at:           parse_time_range(:updated_at),
        date:                 parse_date_range(:date),
        users:                parse_users(:user),
        names:                parse_strings(:name),
        synonym_names:        parse_strings(:synonyms_of),
        children_names:       parse_strings(:children_of),
        locations:            parse_strings(:location),
        projects:             parse_strings(:projects),
        species_lists:        parse_strings(:species_lists),
        has_observation:      parse_boolean(:has_observation, limit: true),
        size:                 parse_size,
        content_types:        parse_string(:content_type),
        has_notes:            parse_boolean(:has_notes),
        notes_has:            parse_string(:notes_has),
        copyright_holder_has: parse_string(:copyright_holder_has),
        license:              parse_license(:license),
        has_votes:            parse_boolean(:has_votes),
        quality:              parse_quality,
        confidence:           parse_confidence,
        ok_for_export:        parse_boolean(:ok_for_export)
      }
    end
    # rubocop:enable Metrics/AbcSize

    def build_object
      params = create_params
      vote = parse_enum(:vote, limit: Image.all_votes)
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

    def create_params
      observations = parse_observations_to_attach_to
      default_date = observations.any? ? observations.first.when : Date.today
      {
        when:             parse_date(:date, default: default_date),
        notes:            parse_string(:notes, default: ""),
        copyright_holder: parse_copyright_holder,
        license:          parse_license(:license, default: user.license),
        original_name:    parse_original_name,
        projects:         parse_projects_to_attach_to,
        observations:     observations
      }
    end

    def upload_params(upload)
      {
        image:          upload.content,
        upload_length:  upload.content_length,
        upload_type:    upload.content_type,
        upload_md5sum:  upload.content_md5
      }
    end

    def update_params
      {
        when:             parse_date(:set_date),
        notes:            parse_string(:set_notes),
        copyright_holder: parse_string(:set_copyright_holder, limit: 100),
        license:          parse_license(:set_license),
        original_name:    parse_string(:set_original, limit: 120)
      }
    end

    def parse_size
      limit = Image.all_sizes - [:full_size]
      parse_enum_range(:has_size, limit: limit)
    end

    def parse_quality
      limit = Range.new(Image.minimum_vote, Image.maximum_vote)
      parse_float_range(:quality, limit: limit)
    end

    def parse_confidence
      limit = Range.new(Vote.minimum_vote, Vote.maximum_vote)
      parse_float_range(:confidence, limit: limit)
    end

    def parse_copyright_holder
      parse_string(:copyright_holder, limit: 100, default: user.legal_name)
    end

    def parse_original_name
      parse_string(:original_name, limit: 120, default: nil)
    end

    def parse_observations_to_attach_to
      parse_observations(:observations, must_have_edit_permission: true) || []
    end

    def parse_projects_to_attach_to
      parse_projects(:projects, must_be_member: true) || []
    end
  end
end
