# frozen_string_literal: true

class Components::MatrixBox
  # Build render data for MatrixBox based on @object type
  module RenderData
    def build_render_data
      case @object
      when ::Image
        extract_image_data
      when Observation
        extract_observation_data
      when RssLog
        extract_rss_log_data
      when User
        extract_user_data
      else
        { id: @object.id, type: :unknown }
      end
    end

    def extract_image_data
      {
        id: @object.id,
        type: :image,
        when: begin
                @object.when.web_date
              rescue StandardError
                nil
              end,
        who: @object.user,
        name: @object.unique_format_name.t,
        what: @object,
        where: nil,
        location: nil,
        image: @object,
        image_link: @object.show_link_args,
        full_width: true
      }
    end

    def extract_observation_data # rubocop:disable Metrics/AbcSize
      data = {
        id: @object.id,
        type: :observation,
        when: @object.when.web_date,
        who: @object.user,
        name: @object.user_format_name(@object.user).t.break_name.small_author,
        what: @object,
        where: @object.where,
        location: @object.location,
        consensus: Observation::NamingConsensus.new(@object),
        detail: @object.rss_log&.detail,
        time: @object.rss_log&.updated_at
      }

      add_observation_image_data(data) if @object.thumb_image_id
      data
    end

    def add_observation_image_data(data)
      data[:image] = @object.thumb_image
      data[:image_link] = @object.show_link_args
      data[:obs] = @object
      data[:full_width] = true
    end

    def extract_rss_log_data
      target = @object.target
      data = {
        id: target&.id || @object.id,
        type: @object.target_type || :rss_log,
        when: target.respond_to?(:when) ? target.when&.web_date : nil,
        who: target&.user,
        what: target || @object,
        detail: @object.detail,
        time: @object.updated_at
      }

      data[:name] = extract_rss_log_name(target)
      add_rss_log_location_data(data, target)
      add_rss_log_image_data(data, target)
      data
    end

    def extract_rss_log_name(target)
      if @object.target_type == :image
        target.unique_format_name.t
      elsif target
        target.format_name.t.break_name.small_author
      else
        @object.format_name.t.break_name.small_author
      end
    end

    def add_rss_log_location_data(data, target)
      return unless target.respond_to?(:location)

      data[:where] = target.where
      data[:location] = target.location
    end

    def add_rss_log_image_data(data, target)
      return unless target.respond_to?(:thumb_image) && target&.thumb_image

      data[:image] = target.thumb_image
      data[:image_link] = target.show_link_args
      data[:obs] = target if target.respond_to?(:is_collection_location)
      data[:full_width] = true
    end

    def extract_user_data
      data = {
        id: @object.id,
        type: :user,
        detail: @object,
        name: @object.unique_text_name,
        what: @object,
        where: @object.location&.name,
        location: @object.location
      }

      add_user_image_data(data) if @object.image_id
      data
    end

    def add_user_image_data(data)
      data[:image] = @object.image
      data[:image_link] = @object.show_link_args
      data[:votes] = false
      data[:full_width] = true
    end
  end
end
