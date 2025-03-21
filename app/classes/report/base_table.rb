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
      tweaker = ProjectTweaker.new
      rows = all_rows.map { |row| Row.new(tweaker.tweak(row)) }
      rows = sort_before(rows)
      extend_data!(rows)
      sort_after(rows.map { |row| format_row(row) })
    end

    def all_rows
      rows_with_location + rows_without_location
    end

    def rows_without_location
      query.select_rows(
        select: without_location_selects.join(","),
        join: [:users, :names],
        where: "observations.location_id IS NULL",
        order: "observations.id ASC"
      )
    end

    def rows_with_location
      query.select_rows(
        select: with_location_selects.join(","),
        join: [:users, :locations, :names],
        order: "observations.id ASC"
      )
    end

    def without_location_selects
      [
        "observations.id",
        "observations.when",
        public_latlng_spec(:lat),
        public_latlng_spec(:lng),
        "observations.alt",
        "observations.specimen",
        "observations.is_collection_location",
        "observations.vote_cache",
        "observations.thumb_image_id",
        "observations.notes",
        "observations.updated_at",
        "users.id",
        "users.login",
        "users.name",
        "names.id",
        "names.text_name",
        "names.author",
        "names.`rank`",
        '""',
        "observations.where",
        '""',
        '""',
        '""',
        '""',
        '""',
        '""'
      ]
    end

    def with_location_selects
      [
        "observations.id",
        "observations.when",
        public_latlng_spec(:lat),
        public_latlng_spec(:lng),
        "observations.alt",
        "observations.specimen",
        "observations.is_collection_location",
        "observations.vote_cache",
        "observations.thumb_image_id",
        "observations.notes",
        "observations.updated_at",
        "users.id",
        "users.login",
        "users.name",
        "names.id",
        "names.text_name",
        "names.author",
        "names.`rank`",
        "locations.id",
        "locations.name",
        "locations.north",
        "locations.south",
        "locations.east",
        "locations.west",
        "locations.high",
        "locations.low"
      ]
    end

    def public_latlng_spec(col)
      "IF(observations.gps_hidden AND " \
        "observations.user_id != #{User.current_id || -1}, " \
        "NULL, observations.#{col})"
    end

    def add_herbarium_labels!(rows, col)
      vals = HerbariumRecord.connection.select_rows(%(
        SELECT ho.observation_id,
          CONCAT(h.initial_det, ": ", h.accession_number)
        FROM herbarium_records h
        JOIN observation_herbarium_records ho ON ho.herbarium_record_id = h.id
        JOIN (#{plain_query}) AS ids ON ids.id = ho.observation_id
      ))
      add_column!(rows, vals, col)
    end

    def add_herbarium_accession_numbers!(rows, col)
      vals = HerbariumRecord.connection.select_rows(%(
        SELECT ho.observation_id,
          GROUP_CONCAT(DISTINCT CONCAT(h.code, "\t", hr.accession_number)
                       SEPARATOR "\n")
        FROM observation_herbarium_records ho
        JOIN herbarium_records hr ON hr.id = ho.herbarium_record_id
        JOIN herbaria h ON h.id = hr.herbarium_id
        JOIN (#{plain_query}) AS ids ON ids.id = ho.observation_id
        WHERE h.code != ""
        GROUP BY ho.observation_id
      ))
      add_column!(rows, vals, col)
    end

    def add_collector_ids!(rows, col)
      vals = CollectionNumber.connection.select_rows(%(
        SELECT co.observation_id,
          GROUP_CONCAT(DISTINCT CONCAT(c.id, "\t", c.name, "\t", c.number)
                       SEPARATOR "\n")
        FROM collection_numbers c
        JOIN observation_collection_numbers co
          ON co.collection_number_id = c.id
        JOIN (#{plain_query}) AS ids ON ids.id = co.observation_id
        GROUP BY co.observation_id
      ))
      add_column!(rows, vals, col)
    end

    def add_image_ids!(rows, col)
      vals = Image.connection.select_rows(%(
        SELECT io.observation_id, io.image_id
        FROM observation_images io
        JOIN (#{plain_query}) AS ids ON ids.id = io.observation_id
      ))
      add_column!(rows, vals, col)
    end

    def plain_query
      # Sometimes the default order requires unnecessary joins!
      query.sql(order: "")
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
