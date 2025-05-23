# frozen_string_literal: true

class API2
  # API for Image
  class ImageAPI < ModelAPI
    def model
      Image
    end

    def high_detail_page_length
      100
    end

    def low_detail_page_length
      1000
    end

    def put_page_length
      1000
    end

    def delete_page_length
      1000
    end

    def low_detail_includes
      [:license]
    end

    def high_detail_includes
      [
        :license,
        :observations,
        :user
      ]
    end

    # Disable cop to keep table style alignment of multipline Hash values
    # rubocop:disable Layout/MultilineOperationIndentation
    def query_params
      {
        id_in_set: parse_array(:image, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        date: parse_range(:date, :date, help: :when_taken),
        by_users: parse_array(:user, :user, help: :uploader),
        locations: parse_array(:location, :location, as: :id),
        observations: parse_array(:observation, :observation, as: :id),
        projects: parse_array(:project, :project, as: :id),
        species_lists: parse_array(:species_list, :species_list, as: :id),
        has_observations: parse(:boolean, :has_observation,
                                limit: true, help: 1),
        sizes: parse(:enum, :size,
                     limit: Image::ALL_SIZES - [:full_size], help: :min_size),
        content_types: parse_array(:enum, :content_type,
                                   limit: Image::ALL_EXTENSIONS),
        has_notes: parse(:boolean, :has_notes),
        notes_has: parse(:string, :notes_has, help: 1),
        copyright_holder_has: parse(:string, :copyright_holder_has, help: 1),
        license: parse(:license, :license),
        has_votes: parse(:boolean, :has_votes),
        quality: parse_range(:quality, :quality),
        confidence: parse_range(:confidence, :confidence),
        ok_for_export: parse(:boolean, :ok_for_export),
        observation_query: parse_observation_query_parameters.compact
      }
    end

    def parse_observation_query_parameters
      parse_names_parameters
    end

    def create_params
      parse_create_params!
      {
        when: parse(:date, :date, help: :when_taken) || @default_date,
        notes: parse(:string, :notes, default: ""),
        copyright_holder: parse(:string, :copyright_holder, limit: 100) ||
                          user.legal_name,
        license: parse(:license, :license) || user.license,
        original_name: parse_original_name(:original_name),
        upload_md5sum: parse(:string, :md5sum),
        projects: parse_array(:project, :projects, must_be_member: true) || [],
        observations: @observations,
        user: @user
      }.merge(upload_params)
    end

    def update_params
      {
        when: parse(:date, :set_date, help: :when_taken),
        notes: parse(:string, :set_notes),
        copyright_holder: parse(:string, :set_copyright_holder, limit: 100),
        license: parse(:license, :set_license),
        original_name: parse_original_name(:set_original_name)
      }
    end
    # rubocop:enable Layout/MultilineOperationIndentation

    def validate_create_params!(_params)
      raise(MissingUpload.new) unless @upload
    end

    def build_object
      super
    ensure
      @upload&.clean_up
    end

    def after_create(img)
      strip = @observations.any?(&:gps_hidden)
      img.process_image(strip: strip) || raise(ImageUploadFailed.new(img))
      @observations.each do |obs|
        obs.update(thumb_image_id: img.id) unless obs.thumb_image_id
        img.log_create_for(obs)
      end
      return unless @vote

      img.change_vote(@user, @vote, anon: @user.votes_anonymous == "yes")
    end

    ############################################################################

    private

    def parse_create_params!
      @observations = parse_array(:observation, :observations,
                                  must_have_edit_permission: true) || []
      @default_date =
        @observations.any? ? @observations.first.when : Time.zone.today
      @vote = parse(:enum, :vote, limit: Image.all_votes)
      @upload = prepare_upload
    end

    def parse_original_name(arg)
      # Important to call parse, even if the guard clause below is true.
      val = parse(:string, arg, limit: 120, help: :original_name)

      # This is just a sanity check for the benefit of the mobile app to make
      # sure it doesn't accidentally explicitly set the original_name even if
      # the user has requested not to save it.  I'm not sure the mobile app
      # has access to that preference.
      return nil if @user&.keep_filenames == "toss"

      val
    end

    def upload_params
      return {} unless @upload

      {
        image: @upload.content,
        upload_length: @upload.content_length,
        upload_type: @upload.content_type,
        upload_md5sum: @upload.content_md5
      }.compact
    end
  end
end
