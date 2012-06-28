# encoding: utf-8

class API
  class ImageAPI < ModelAPI
    self.model = Image

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :user,
    ]

    def query_params
      {
        :where           => sql_id_condition,
        :created         => parse_time_ranges(:created),
        :modified        => parse_time_ranges(:modified),
        :users           => parse_users(:user),
        :date            => parse_date_ranges(:date),
        :names           => parse_names(:name),
        :synonym_names   => parse_names(:synonyms_of),
        :children_names  => parse_names(:children_of),
        :locations       => parse_locations(:location),
        :species_lists   => parse_species_lists(:species_lists),
        :has_observation => parse_boolean(:has_observation),
        :size            => parse_enum_ranges(:has_size, :limit => Image.all_sizes - [:full_size]),
        :content_types   => parse_strings(:content_type),
        :has_notes       => parse_boolean(:has_notes),
        :notes_has       => parse_strings(:notes_has),
        :copyright_holder_has => parse_strings(:copyright_holder_has),
        :license         => parse_licenses(:license),
        :has_votes       => parse_boolean(:has_votes),
        :quality         => parse_float_ranges(:quality),
        :confidence      => parse_float_ranges(:confidence),
        :ok_for_export   => parse_boolean(:ok_for_export),
      }
    end

    def build_object
      observations = parse_observations(:observation, :default => [])
      default_date = observations.any? ? observations.first.when : Time.now
      upload = prepare_upload or raise MissingUpload.new

      params = {
        :when             => parse_date(:date, :default => default_date),
        :notes            => parse_string(:notes, :default => ''),
        :copyright_holder => parse_string(:copyright_holder, :limit => 100, :default => user.legal_name),
        :license          => parse_license(:license, :default => user.license),
        :original_name    => parse_string(:original_name, :limit => 120, :default => nil),
        :observations     => observations,
        :projects         => parse_projects(:project, :default => []),
        :image            => upload.content,
        :upload_length    => upload.content_length,
        :upload_type      => upload.content_type,
        :upload_md5sum    => upload.content_md5,
      }
      done_parsing_parameters!

      img = model.new(params)
      img.save or raise CreateFailed.new(img)
      img.process_image or raise ImageUploadFailed.new(img)

      if observations.any?
        for obs in observations
          unless obs.thumb_image_id
            obs.update_attributes(:thumb_image_id => img.id)
          end
          obs.log_create_image(img)
        end
      end

      return obs
    ensure
      upload.clean_up
    end

    def update_params
      {
        :when          => parse_date(:set_date),
        :notes         => parse_string(:set_notes),
        :copyright_holder => parse_string(:set_copyright_holder, :limit => 100),
        :license       => parse_license(:set_license),
        :original_name => parse_string(:set_original, :limit => 120),
      }
    end
  end
end

