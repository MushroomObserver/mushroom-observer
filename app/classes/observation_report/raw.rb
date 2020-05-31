# frozen_string_literal: true

module ObservationReport
  # Default CSV report.
  class Raw < ObservationReport::CSV
    # rubocop:disable Metrics/MethodLength
    def labels
      %w[
        observation_id
        user_id
        user_login
        user_name
        collection_date
        has_specimen
        original_label
        consensus_name_id
        consensus_name
        consensus_author
        consensus_rank
        confidence
        location_id
        country
        state
        county
        location
        latitude
        longitude
        altitude
        north_edge
        south_edge
        east_edge
        west_edge
        max_altitude
        min_altitude
        is_collection_location
        thumbnail_image_id
        notes
        url
      ]
    end

    # rubocop:disable Metrics/AbcSize Metrics/MethodLength
    def format_row(row)
      [
        row.obs_id,
        row.user_id,
        row.user_login,
        row.user_name,
        row.obs_when,
        row.obs_specimen,
        row.val(1),
        row.name_id,
        row.name_text_name,
        row.name_author,
        row.name_rank,
        row.obs_vote_cache,
        row.loc_id,
        row.country,
        row.state,
        row.county,
        row.locality,
        row.obs_lat,
        row.obs_long,
        row.obs_alt,
        row.loc_north,
        row.loc_south,
        row.loc_east,
        row.loc_west,
        row.loc_high,
        row.loc_low,
        row.obs_is_collection_location,
        row.obs_thumb_image_id,
        row.obs_notes,
        row.obs_url
      ]
    end

    def extend_data!(rows)
      add_herbarium_labels!(rows, 1)
    end

    def sort_after(rows)
      rows.sort_by { |row| row[0].to_i }
    end
  end
end
