# frozen_string_literal: true

module Report
  # base table class
  class BaseTable < Base
    attr_accessor :query

    OBS_SIMPLE_SELECTS = {
      obs_id: :id,
      obs_when: :when,
      obs_alt: :alt,
      obs_specimen: :specimen,
      obs_is_collection_location: :is_collection_location,
      obs_vote_cache: :vote_cache,
      obs_thumb_image_id: :thumb_image_id,
      obs_notes: :notes,
      obs_updated_at: :updated_at
    }.freeze

    USER_SELECTS = {
      user_id: :id,
      user_login: :login,
      user_name: :name
    }.freeze

    NAME_SELECTS = {
      name_id: :id,
      name_text_name: :text_name,
      name_search_name: :search_name,
      name_author: :author,
      name_rank: :rank
    }.freeze

    LOCATION_SELECTS = {
      loc_id: :id,
      loc_name: :name,
      loc_north: :north,
      loc_south: :south,
      loc_east: :east,
      loc_west: :west,
      loc_high: :high,
      loc_low: :low
    }.freeze

    def initialize(args)
      super
      self.query = args[:query]
      raise("Report initialized without query!") unless query
    end

    # Stub for subclasses which need to add other columns to table.
    def extend_data!(data); end

    # Stub for subclasses to sort results before formatting data.
    def sort_before(data)
      data
    end

    # Stub for subclasses to sort results after formatting data.
    def sort_after(data)
      data
    end

    def formatted_rows
      tweaker = ProjectTweaker.new(user:)
      rows = all_rows.map do |raw|
        verify_row_keys!(raw)
        Row.new(tweaker.tweak(raw))
      end
      rows = sort_before(rows)
      extend_data!(rows)
      rows.select! { |row| include_row?(row) }
      sort_after(rows.map { |row| format_row(row) })
    end

    def include_row?(_row) = true

    def all_rows
      rows_with_location + rows_without_location
    end

    # Catch select_all returning a row that's missing one or more
    # of the columns our SELECT requested — the failure mode #3637
    # was added to detect (intermittent column drop / misalignment).
    # Under named-hash storage a missing key only becomes a silent
    # nil downstream, so this guard surfaces it loudly at the row
    # boundary instead.
    def verify_row_keys!(raw)
      missing = Row::BASE_KEYS - raw.keys.map(&:to_s)
      return if missing.empty?

      raise(
        "Report::BaseTable row missing expected columns: " \
        "#{missing.inspect}. Got keys: #{raw.keys.inspect}. " \
        "Row: #{raw.inspect}"
      )
    end

    private

    def rows_without_location
      Observation.connection.select_all(
        query.scope.joins(:user, :name).
        where(location_id: nil).select(without_location_selects).
        reorder(Observation[:id].asc)
      ).to_a
    end

    def without_location_selects
      observation_selects + user_selects + name_selects + blanks_for_location
    end

    def rows_with_location
      Observation.connection.select_all(
        query.scope.joins(:user, :location, :name).
        select(with_location_selects).
        reorder(Observation[:id].asc)
      ).to_a
    end

    def with_location_selects
      observation_selects + user_selects + name_selects + location_selects
    end

    def observation_selects
      obs_simple_selects +
        [public_latlng_spec(:lat).as("obs_lat"),
         public_latlng_spec(:lng).as("obs_lng")]
    end

    def obs_simple_selects
      OBS_SIMPLE_SELECTS.map { |aliaz, attr| Observation[attr].as(aliaz.to_s) }
    end

    def public_latlng_spec(col)
      Observation[:gps_hidden].eq(true).
        and(Observation[:user_id].not_eq(user&.id || -1)).
        when(true).then(nil).else(Observation[col])
    end

    def user_selects
      USER_SELECTS.map { |aliaz, attr| User[attr].as(aliaz.to_s) }
    end

    def name_selects
      NAME_SELECTS.map { |aliaz, attr| Name[attr].as(aliaz.to_s) }
    end

    # For observations with no Location row, fill the loc_name slot
    # with `observations.where` (the user-typed place string). This
    # preserves the legacy behavior where row.loc_name returned the
    # `where` text for without-location obs. The other loc_* slots
    # come back as empty strings so the row still has every key.
    def blanks_for_location
      LOCATION_SELECTS.keys.map do |aliaz|
        if aliaz == :loc_name
          Observation[:where].as(aliaz.to_s)
        else
          Arel::Nodes.build_quoted("").as(aliaz.to_s)
        end
      end
    end

    def location_selects
      LOCATION_SELECTS.map { |aliaz, attr| Location[attr].as(aliaz.to_s) }
    end

    # Extension column key for row.add_val / row.val.
    # Each add_*! takes a Symbol key (e.g. :collector_ids) and the
    # subclass reads it back as row.val(:collector_ids).

    # "+" is the required Arel Extensions syntax for SQL CONCAT
    # rubocop:disable Style/StringConcatenation
    def add_herbarium_labels!(rows, key)
      vals = HerbariumRecord.joins(:observations).
             merge(plain_query).
             select(ObservationHerbariumRecord[:observation_id],
                    HerbariumRecord[:initial_det] + ": " +
                     HerbariumRecord[:accession_number]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, key)
    end
    # rubocop:enable Style/StringConcatenation

    # rubocop:disable Metrics/AbcSize
    def add_herbarium_accession_numbers!(rows, key)
      gpc = 'GROUP_CONCAT(DISTINCT CONCAT(herbaria.code, "\t", ' \
            'herbarium_records.accession_number) SEPARATOR "\n")'
      vals = Herbarium.joins(herbarium_records: :observations).
             where.not(Herbarium[:code].eq("")).
             merge(plain_query).
             group(ObservationHerbariumRecord[:observation_id]).
             select(ObservationHerbariumRecord[:observation_id], Arel.sql(gpc)).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, key)
    end
    # rubocop:enable Metrics/AbcSize

    def add_collector_ids!(rows, key)
      gpc = 'GROUP_CONCAT(DISTINCT CONCAT(collection_numbers.id, "\t", ' \
            'collection_numbers.name, "\t", collection_numbers.number) ' \
            'SEPARATOR "\n")'
      vals = CollectionNumber.joins(:observations).
             merge(plain_query).
             group(ObservationCollectionNumber[:observation_id]).
             select(ObservationCollectionNumber[:observation_id],
                    Arel.sql(gpc)).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, key)
    end

    def add_field_slips!(rows, key)
      vals = Observation.joins(occurrence: :field_slip).
             merge(plain_query).
             select(Observation[:id], FieldSlip[:code]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, key)
    end

    def add_image_ids!(rows, key)
      vals = Image.joins(:observations).
             merge(plain_query).
             select(ObservationImage[:observation_id],
                    ObservationImage[:image_id]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, key)
    end

    def add_sequence_ids!(rows, key)
      vals = Sequence.joins(:observation).
             merge(plain_query).
             select(Sequence[:observation_id], Sequence[:id]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, key)
    end

    def plain_query
      # Sometimes the default order requires unnecessary joins!
      # Non-primary observations already excluded by query scope.
      query.scope.reorder("")
    end

    def add_column!(rows, vals, key)
      hash = {}
      vals.each do |id, val|
        if hash[id]
          hash[id] += ", #{val}"
        else
          hash[id] = val.to_s
        end
      end
      rows.each do |row|
        val = hash[row.obs_id] || nil
        row.add_val(val, key)
      end
    end
  end
end
