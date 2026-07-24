# frozen_string_literal: true

class Components::Matrix::Box
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
        name: @object.format_name(@object.user).t.break_name.small_author,
        what: @object,
        where: @object.where,
        location: @object.location,
        occurrence: @object.occurrence,
        consensus: Observation::NamingConsensus.new(@object),
        detail: rss_log_detail_tag(@object.rss_log),
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
        detail: rss_log_detail_tag(@object),
        time: @object.updated_at
      }

      data[:name] = extract_rss_log_name(target)
      add_rss_log_location_data(data, target)
      add_rss_log_image_data(data, target)
      data
    end

    # The [tag, args] pair identifying an RssLog's most recent update,
    # unresolved -- Footer#render_rss_detail resolves it at render
    # time (was RssLog#detail/#latest_message/etc., moved here since
    # picking which log entry to summarize is a data decision, not a
    # model concern -- RssLog#parse_log/#orphan?/#target_type/
    # #created_at are all it needs, all already public).
    def rss_log_detail_tag(rss_log)
      return nil unless rss_log

      log = rss_log.parse_log
      if rss_log.orphan?
        penultimate_message_tag(rss_log, log)
      elsif target_recently_created?(rss_log, log)
        creation_message_tag(rss_log, log)
      else
        latest_message_tag(log)
      end
    end

    def target_recently_created?(rss_log, log)
      _latest_tag, _latest_args, latest_time = log.first
      first_time = rss_log.created_at || log.last[2]
      latest_time && first_time && latest_time < first_time + 1.minute
    end

    def latest_message_tag(log)
      tag, args = log.first
      [tag, args]
    end

    def penultimate_message_tag(rss_log, log)
      tag, args = log[1]
      if tag.present?
        [tag,
         args]
      else
        [:rss_destroyed, { type: rss_log.target_type }]
      end
    end

    def creation_message_tag(rss_log, log)
      if [:observation, :species_list].include?(rss_log.target_type)
        [:rss_created_at, { type: rss_log.target_type }]
      else
        tag, args = log.last
        [tag, args]
      end
    end

    def extract_rss_log_name(target)
      if @object.target_type == :image
        target.unique_format_name.t
      elsif target
        rss_log_format_name(target)
      else
        rss_log_format_name(@object)
      end
    end

    def rss_log_format_name(obj)
      obj.format_name(@user).t.break_name.small_author
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
