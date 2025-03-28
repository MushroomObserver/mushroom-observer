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
      # query.select_rows(
      #   select: without_location_selects.join(","),
      #   join: [:users, :names],
      #   where: "observations.location_id IS NULL",
      #   order: "observations.id ASC"
      # )
      fred = query.query.joins(:user, :name).
        where(location_id: nil).select(without_location_selects).
        reorder(Observation[:id].asc).pluck
      debugger
      fred
      # SELECT `observations`.`id`,
      #        `observations`.`when`,
      #        IF(observations.gps_hidden AND observations.user_id != -1,
      #           NULL, observations.lat),
      #        IF(observations.gps_hidden AND observations.user_id != -1,
      #           NULL, observations.lng),
      #        `observations`.`alt`,
      #        `observations`.`specimen`,
      #        `observations`.`is_collection_location`,
      #        `observations`.`vote_cache`,
      #        `observations`.`thumb_image_id`,
      #        `observations`.`notes`,
      #        `observations`.`updated_at`,
      #        `users`.`id`,
      #        `users`.`login`,
      #        `users`.`name`,
      #        `names`.`id`,
      #        `names`.`text_name`,
      #        `names`.`author`,
      #        `names`.`rank`,
      #        \"\",
      #        `observations`.`where`
      # FROM `observations`
      # INNER JOIN `users` ON `users`.`id` = `observations`.`user_id`
      # INNER JOIN `names` ON `names`.`id` = `observations`.`name_id`
      # WHERE `observations`.`location_id` IS NULL
      # ORDER BY `observations`.`id` ASC
      # (ruby) fred.first here, 29 vals
      # [98434105,
      #  Fri, 04 Apr 2014 00:05:03.000000000 EDT -04:00,
      #  Fri, 15 Sep 2023 00:05:03.000000000 EDT -04:00,
      #  Thu, 07 Jun 2012,
      #  430653790,
      #  false,
      #  {},
      #  nil,
      #  456981406,
      #  nil,
      #  true,
      #  0.0,
      #  0,
      #  nil,
      #  488320040,
      #  nil,
      #  nil,
      #  "Briceland, California, USA",
      #  nil,
      #  " lichen ",
      #  "Petigera",
      #  "",
      #  false,
      #  nil,
      #  Fri, 04 Apr 2014 00:05:03.000000000 EDT -04:00,
      #  true,
      #  nil,
      #  nil,
      #  nil]

      # (ruby) fred.first on main, 26 vals
      # [31426256,
      #  Sun, 24 Jun 2007,
      #  nil,
      #  nil,
      #  nil,
      #  0,
      #  1,
      #  0.0,
      #  nil,
      #  "---\n:Other: From somewhere else\n",
      #  2007-06-24 09:00:01 UTC,
      #  241228755,
      #  "rolf",
      #  "Rolf Singer",
      #  561573041,
      #  "Agaricus campestras",
      #  "L.",
      #  4,
      #  547147019,
      #  "Burbank, California, USA",
      #  34.22,
      #  34.15,
      #  -118.29,
      #  -118.37,
      #  294.0,
      #  148.0]
    end

    def rows_with_location
      # query.select_rows(
      #   select: with_location_selects.join(","),
      #   join: [:users, :locations, :names],
      #   order: "observations.id ASC"
      # )
      Observation.merge(query.query).joins(:user, :location, :name).
        select(with_location_selects).
        reorder(Observation[:id].asc).pluck
    end

    def without_location_selects # rubocop:disable Metrics/AbcSize
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
        Observation[:updated_at],
        User[:id],
        User[:login],
        User[:name],
        Name[:id],
        Name[:text_name],
        Name[:author],
        Name[:rank],
        '""',
        Observation[:where],
        '""',
        '""',
        '""',
        '""',
        '""',
        '""'
      ]
    end

    def with_location_selects # rubocop:disable Metrics/AbcSize
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
        Observation[:updated_at],
        User[:id],
        User[:login],
        User[:name],
        Name[:id],
        Name[:text_name],
        Name[:author],
        Name[:rank],
        Location[:id],
        Location[:name],
        Location[:north],
        Location[:south],
        Location[:east],
        Location[:west],
        Location[:high],
        Location[:low]
      ]
    end

    def public_latlng_spec(col)
      Arel.sql("IF(observations.gps_hidden AND " \
        "observations.user_id != #{User.current_id || -1}, " \
        "NULL, observations.#{col})")
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
      query.query.reorder("").to_sql
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
