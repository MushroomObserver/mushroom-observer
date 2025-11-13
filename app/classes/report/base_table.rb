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
      Observation.connection.select_rows(
        query.scope.joins(:user, :name).
        where(location_id: nil).select(without_location_selects).
        reorder(Observation[:id].asc)
      )
    end

    def without_location_selects
      observation_selects + user_selects + name_selects + blanks_for_location
    end

    def rows_with_location
      Observation.connection.select_rows(
        query.scope.joins(:user, :location, :name).
        select(with_location_selects).
        reorder(Observation[:id].asc)
      )
    end

    def with_location_selects
      observation_selects + user_selects + name_selects + location_selects
    end

    def observation_selects
      [
        Observation[:id],
        Observation[:when],
        public_latlng_spec(:lat),
        public_latlng_spec(:lng),
        Observation[:alt],
        Observation[:specimen],
        Observation[:is_collection_location],
        Observation[:vote_cache],
        Observation[:thumb_image_id],
        Observation[:notes],
        Observation[:updated_at]
      ].freeze
    end

    def public_latlng_spec(col)
      Observation[:gps_hidden].eq(true).
        and(Observation[:user_id].not_eq(user&.id || -1)).
        when(true).then(nil).else(Observation[col])
    end

    def user_selects
      [
        User[:id],
        User[:login],
        User[:name]
      ].freeze
    end

    def name_selects
      [
        Name[:id],
        Name[:text_name],
        Name[:author],
        Name[:rank]
      ].freeze
    end

    def blanks_for_location
      [
        Arel::Nodes.build_quoted("").as("location_id"),
        Observation[:where],
        Arel::Nodes.build_quoted("").as("location_north"),
        Arel::Nodes.build_quoted("").as("location_south"),
        Arel::Nodes.build_quoted("").as("location_east"),
        Arel::Nodes.build_quoted("").as("location_west"),
        Arel::Nodes.build_quoted("").as("location_high"),
        Arel::Nodes.build_quoted("").as("location_low")
      ].freeze
    end

    def location_selects
      [
        Location[:id],
        Location[:name],
        Location[:north],
        Location[:south],
        Location[:east],
        Location[:west],
        Location[:high],
        Location[:low]
      ].freeze
    end

    # "+" is the required Arel Extensions syntax for SQL CONCAT
    # rubocop:disable Style/StringConcatenation
    def add_herbarium_labels!(rows, col)
      vals = HerbariumRecord.joins(:observations).
             merge(plain_query).
             select(ObservationHerbariumRecord[:observation_id],
                    HerbariumRecord[:initial_det] + ": " +
                     HerbariumRecord[:accession_number]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, col)
    end
    # rubocop:enable Style/StringConcatenation

    # rubocop:disable Metrics/AbcSize
    def add_herbarium_accession_numbers!(rows, col)
      gpc = 'GROUP_CONCAT(DISTINCT CONCAT(herbaria.code, "\t", ' \
            'herbarium_records.accession_number) SEPARATOR "\n")'
      vals = Herbarium.joins(herbarium_records: :observations).
             where.not(Herbarium[:code].eq("")).
             merge(plain_query).
             group(ObservationHerbariumRecord[:observation_id]).
             select(ObservationHerbariumRecord[:observation_id], Arel.sql(gpc)).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, col)
    end
    # rubocop:enable Metrics/AbcSize

    def add_collector_ids!(rows, col)
      gpc = 'GROUP_CONCAT(DISTINCT CONCAT(collection_numbers.id, "\t", ' \
            'collection_numbers.name, "\t", collection_numbers.number) ' \
            'SEPARATOR "\n")'
      vals = CollectionNumber.joins(:observations).
             merge(plain_query).
             group(ObservationCollectionNumber[:observation_id]).
             select(ObservationCollectionNumber[:observation_id],
                    Arel.sql(gpc)).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, col)
    end

    def add_field_slips!(rows, col)
      vals = FieldSlip.joins(:observation).
             merge(plain_query).
             select(FieldSlip[:observation_id], FieldSlip[:code]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, col)
    end

    def add_image_ids!(rows, col)
      vals = Image.joins(:observations).
             merge(plain_query).
             select(ObservationImage[:observation_id],
                    ObservationImage[:image_id]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, col)
    end

    def add_sequence_ids!(rows, col)
      vals = Sequence.joins(:observation).
             merge(plain_query).
             select(Sequence[:observation_id], Sequence[:id]).
             map { |rec| rec.attributes.values[0..1] }
      add_column!(rows, vals, col)
    end

    def plain_query
      # Sometimes the default order requires unnecessary joins!
      query.scope.reorder("")
    end

    def add_column!(rows, vals, col)
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
        row.add_val(val, col)
      end
    end
  end
end
