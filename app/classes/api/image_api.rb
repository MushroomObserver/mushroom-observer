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
        where:           sql_id_condition,
        created_at:      parse_range(:time, :created_at),
        updated_at:      parse_range(:time, :updated_at),
        date:            parse_range(:date, :date, help: :when_taken),
        users:           parse_array(:user, :user, help: :uploader),
        locations:       parse_array(:location, :location, as: :id),
        observations:    parse_array(:observation, :observation, as: :id),
        projects:        parse_array(:project, :project, as: :id),
        species_lists:   parse_array(:species_list, :species_list, as: :id),
        has_observation: parse(:boolean, :has_observation,
                               limit: true, help: 1),
        size:            parse(:enum, :size,
                               limit: Image.all_sizes - [:full_size],
                               help: :min_size),
        content_types:   parse_array(:enum, :content_type,
                                     limit: Image.all_extensions),
        has_notes:       parse(:boolean, :has_notes),
        notes_has:       parse(:string, :notes_has, help: 1),
        copyright_holder_has: parse(:string, :copyright_holder_has, help: 1),
        license:         parse(:license, :license),
        has_votes:       parse(:boolean, :has_votes),
        quality:         parse_range(:quality, :quality),
        confidence:      parse_range(:confidence, :confidence),
        ok_for_export:   parse(:boolean, :ok_for_export)
      }.merge(parse_names_parameters)
    end
    # rubocop:enable Metrics/AbcSize

    # This probably belongs in a shared module somewhere.
    def parse_names_parameters
      args = {
        names:            parse_array(:name, :name, as: :id),
        include_synonyms: parse(:boolean, :include_synonyms),
        include_subtaxa:  parse(:boolean, :include_subtaxa)
      }
      if names = parse_array(:name, :synonyms_of, as: :id)
        args[:names]            = names
        args[:include_synonyms] = true
      end
      if names = parse_array(:name, :children_of, as: :id)
        args[:names]           = names
        args[:include_subtaxa] = true
        args[:exclude_original_names] = true
      end
      deprecate_parameter(:synonyms_of)
      deprecate_parameter(:children_of)
      args
    end

    def create_params
      parse_create_params!
      {
        when:             parse(:date, :date, help: :when_taken) ||
          @default_date,
        notes:            parse(:string, :notes, default: ""),
        copyright_holder: parse(:string, :copyright_holder, limit: 100) ||
          user.legal_name,
        license:          parse(:license, :license) || user.license,
        original_name:    parse(:string, :original_name,
                                limit: 120, help: :original_name),
        projects:         parse_array(:project, :projects,
                                      must_be_member: true) || [],
        observations:     @observations,
        user:             @user
      }.merge(upload_params)
    end

    def update_params
      {
        when:             parse(:date, :set_date, help: :when_taken),
        notes:            parse(:string, :set_notes),
        copyright_holder: parse(:string, :set_copyright_holder, limit: 100),
        license:          parse(:license, :set_license),
        original_name:    parse(:string, :set_original_name,
                                limit: 120, help: :original_name)
      }
    end

    def validate_create_params!(_params)
      raise MissingUpload.new unless @upload
    end

    def build_object
      super
    ensure
      @upload&.clean_up
    end

    def after_create(img)
      strip = @observations.any?(&:gps_hidden)
      img.process_image(strip) || raise(ImageUploadFailed.new(img))
      @observations.each do |obs|
        obs.update(thumb_image_id: img.id) unless obs.thumb_image_id
        obs.log_create_image(img)
      end
      return unless @vote

      img.change_vote(@user, @vote, (@user.votes_anonymous == :yes))
    end

    ############################################################################

    private

    def parse_create_params!
      @observations = parse_array(:observation, :observations,
                                  must_have_edit_permission: true) || []
      @default_date = @observations.any? ? @observations.first.when : Date.today
      @vote = parse(:enum, :vote, limit: Image.all_votes)
      @upload = prepare_upload
    end

    def upload_params
      return {} unless @upload

      {
        image:            @upload.content,
        upload_length:    @upload.content_length,
        upload_type:      @upload.content_type,
        upload_md5sum:    @upload.content_md5
      }
    end
  end
end
