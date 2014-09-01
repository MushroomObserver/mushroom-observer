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
        :where                => sql_id_condition,
        :created_at           => parse_time_range(:created_at),
        :updated_at           => parse_time_range(:updated_at),
        :date                 => parse_date_range(:date),
        :users                => parse_users(:user),
        :names                => parse_strings(:name),
        :synonym_names        => parse_strings(:synonyms_of),
        :children_names       => parse_strings(:children_of),
        :locations            => parse_strings(:location),
        :projects             => parse_strings(:projects),
        :species_lists        => parse_strings(:species_lists),
        :has_observation      => parse_boolean(:has_observation, :limit => true),
        :size                 => parse_enum_range(:has_size, :limit => Image.all_sizes - [:full_size]),
        :content_types        => parse_string(:content_type),
        :has_notes            => parse_boolean(:has_notes),
        :notes_has            => parse_string(:notes_has),
        :copyright_holder_has => parse_string(:copyright_holder_has),
        :license              => parse_license(:license),
        :has_votes            => parse_boolean(:has_votes),
        :quality              => parse_float_range(:quality, :limit => [Image.minimum_vote..Image.maximum_vote]),
        :confidence           => parse_float_range(:confidence, :limit => [Vote.minimum_vote..Vote.maximum_vote]),
        :ok_for_export        => parse_boolean(:ok_for_export),
      }
    end

    def build_object
      observations = parse_observations(:observations, :default => [], :must_have_edit_permission => true)
      default_date = observations.any? ? observations.first.when : Date.today
      vote = parse_enum(:vote, :limit => Image.all_votes)

      params = {
        :when             => parse_date(:date, :default => default_date),
        :notes            => parse_string(:notes, :default => ''),
        :copyright_holder => parse_string(:copyright_holder, :limit => 100, :default => user.legal_name),
        :license          => parse_license(:license, :default => user.license),
        :original_name    => parse_string(:original_name, :limit => 120, :default => nil),
        :projects         => parse_projects(:projects, :default => [], :must_be_member => true),
        :observations     => observations,
      }
      if upload = prepare_upload
        params.merge!(
          :image          => upload.content,
          :upload_length  => upload.content_length,
          :upload_type    => upload.content_type,
          :upload_md5sum  => upload.content_md5
        )
      end
      done_parsing_parameters!
      raise MissingUpload.new if !upload

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

      if vote
        img.change_vote(@user, vote, (@user.votes_anonymous == :yes))
      end

      return img
    ensure
      upload.clean_up if upload
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

