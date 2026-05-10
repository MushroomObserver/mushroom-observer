# frozen_string_literal: true

module Report
  # Default CSV report.
  class Raw < CSV
    def labels # rubocop:disable Metrics/MethodLength
      %w[
        observation_id
        user_id
        user_login
        user_name
        collection_date
        field_slip
        has_specimen
        original_label
        collection_numbers
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

    def format_row(row) # rubocop:disable Metrics/MethodLength
      [
        row.obs_id,
        row.user_id,
        row.user_login,
        row.user_name,
        row.obs_when,
        row.val(:field_slips),
        row.obs_specimen,
        row.val(:herbarium_labels),
        row.val(:collector_ids),
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
        row.obs_lng,
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
      add_field_slips!(rows, :field_slips)
      add_herbarium_labels!(rows, :herbarium_labels)
      add_collector_ids!(rows, :collector_ids)
    end

    def sort_after(rows)
      rows.sort_by { |row| row[0].to_i }
    end
  end
end
