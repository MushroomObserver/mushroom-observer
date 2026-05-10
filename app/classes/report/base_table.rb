# frozen_string_literal: true

module Report
  # base table class
  class BaseTable < Base
    attr_accessor :query

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
      rows = all_rows.map { |row| Row.new(tweaker.tweak(row)) }
      rows = sort_before(rows)
      extend_data!(rows)
      sort_after(rows.map { |row| format_row(row) })
    end

    def all_rows
      rows_with_location + rows_without_location
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
      cols = obs_simple_selects
      cols.insert(2, public_latlng_spec(:lat).as("obs_lat"),
                  public_latlng_spec(:lng).as("obs_lng"))
      cols.freeze
    end

    def obs_simple_selects
      [[:id, "obs_id"], [:when, "obs_when"], [:alt, "obs_alt"],
       [:specimen, "obs_specimen"],
       [:is_collection_location, "obs_is_collection_location"],
       [:vote_cache, "obs_vote_cache"],
       [:thumb_image_id, "obs_thumb_image_id"],
       [:notes, "obs_notes"],
       [:updated_at, "obs_updated_at"]].
        map { |attr, alias_| Observation[attr].as(alias_) }
    end

    def public_latlng_spec(col)
      Observation[:gps_hidden].eq(true).
        and(Observation[:user_id].not_eq(user&.id || -1)).
        when(true).then(nil).else(Observation[col])
    end

    def user_selects
      [
        User[:id].as("user_id"),
        User[:login].as("user_login"),
        User[:name].as("user_name")
      ].freeze
    end

    def name_selects
      [
        Name[:id].as("name_id"),
        Name[:text_name].as("name_text_name"),
        Name[:author].as("name_author"),
        Name[:rank].as("name_rank")
      ].freeze
    end

    # For observations with no Location row, fill the loc_name slot
    # with `observations.where` (the user-typed place string). This
    # preserves the legacy behavior where row.loc_name returned the
    # `where` text for without-location obs.
    def blanks_for_location
      [
        Arel::Nodes.build_quoted("").as("loc_id"),
        Observation[:where].as("loc_name"),
        Arel::Nodes.build_quoted("").as("loc_north"),
        Arel::Nodes.build_quoted("").as("loc_south"),
        Arel::Nodes.build_quoted("").as("loc_east"),
        Arel::Nodes.build_quoted("").as("loc_west"),
        Arel::Nodes.build_quoted("").as("loc_high"),
        Arel::Nodes.build_quoted("").as("loc_low")
      ].freeze
    end

    def location_selects
      [
        Location[:id].as("loc_id"),
        Location[:name].as("loc_name"),
        Location[:north].as("loc_north"),
        Location[:south].as("loc_south"),
        Location[:east].as("loc_east"),
        Location[:west].as("loc_west"),
        Location[:high].as("loc_high"),
        Location[:low].as("loc_low")
      ].freeze
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
