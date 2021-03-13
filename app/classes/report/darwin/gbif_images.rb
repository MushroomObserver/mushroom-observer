# frozen_string_literal: true

module Report
  module Darwin
    # Darwin Core Observations format.
    class GbifImages < Report::CSV
      VOTE_CUTOFF = 2.5
      PROJECTION_ATTRIBUTES = [[:images, :id],
                               [:images, :when],
                               [:images, :copyright_holder],
                               [:images_observations, :observation_id],
                               [:observations, :updated_at],
                               [:observations, :when, "obs_when"],
                               [:observations, :lat],
                               [:observations, :long],
                               [:observations, :alt],
                               [:observations, :notes],
                               [:names, :text_name],
                               [:names, :author],
                               [:names, :rank],
                               [:locations, :name, "location_name"],
                               [:locations, :north],
                               [:locations, :south],
                               [:locations, :east],
                               [:locations, :west],
                               [:locations, :high],
                               [:locations, :low],
                               [:users, :name],
                               [:users, :login],
                               [:licenses, :url, "license_url"]].freeze

      attr_accessor :query

      self.separator = "\t"

      def initialize(args)
        super(args)
        initialize_query
      end

      def initialize_query
        self.query = tables[:images]
        add_joins
        add_project
        add_conditions
      end

      def add_conditions
        add_observation_conditions(tables[:observations])
        query.where(tables[:images][:ok_for_export].eq(1))
        add_name_conditions(tables[:names])
      end

      def add_observation_conditions(table)
        query.where(table[:vote_cache].gteq(VOTE_CUTOFF))
        query.where(table[:gps_hidden].eq(0))
      end

      def add_name_conditions(table)
        query.where(table[:ok_for_export].eq(1))
        query.where(table[:deprecated].eq(0))
        query.where(table[:text_name].does_not_match('%"%'))
        add_rank_condition(table, [:Species, :Genus])
      end

      def add_rank_condition(table, ranks)
        query.where(table[:rank].in(ranks.map { |rank| Name.ranks[rank] }))
      end

      def tables
        @tables ||= {
          images: Image.arel_table,
          images_observations: Arel::Table.new(:images_observations),
          licenses: License.arel_table,
          locations: Location.arel_table,
          names: Name.arel_table,
          observations: Observation.arel_table,
          users: User.arel_table
        }
      end

      def add_joins
        join_table(:images_observations, :image_id, attribute(:images, :id))
        join_table(:observations, :id,
                   attribute(:images_observations, :observation_id))
        join_table(:names, :id, attribute(:observations, :name_id))
        join_table(:locations, :id, attribute(:observations, :location_id))
        join_table(:users, :id, attribute(:images, :user_id))
        join_table(:licenses, :id, attribute(:images, :license_id))
      end

      def join_table(join_name, join_field, attribute)
        table = tables[join_name]
        join_attribute = table[join_field]
        self.query = query.join(table).on(join_attribute.eq(attribute))
      end

      def add_project
        query.project(*project_attributes)
      end

      def project_attributes
        PROJECTION_ATTRIBUTES.map do |spec|
          result = attribute(spec[0], spec[1])
          spec.length > 2 ? result.as(spec[2]) : result
        end
      end

      def attribute(table_name, field)
        tables[table_name][field]
      end

      def formatted_rows
        @formatted_rows = sort_after(rows.map { |row| format_image_row(row) })
      end

      def rows
        @rows ||= ActiveRecord::Base.connection.exec_query(query.to_sql)
      end

      def observations
        return @observations if @taxa

        obs_hash = {}
        rows.each { |row| obs_hash[row["observation_id"]] = row }
        @observations = obs_hash.values
      end

      def labels
        %w[
          identifier
          type
          format
          accessURL
          furtherInformationURL
          created
          creator
          license
          rightsHolder
        ]
      end

      def sort_after(rows)
        rows.sort_by { |row| row[0].to_i }
      end

      private

      def image_url(id)
        "https://mushroomobserver.org/images/640/#{id}.jpg"
      end

      def show_image_url(id)
        "https://mushroomobserver.org/image/show_image/#{id}"
      end

      def format_image_row(row)
        [row["observation_id"].to_s,
         "StillImage",
         "image/jpeg",
         image_url(row["id"]),
         show_image_url(row["id"]),
         row["when"].to_s,
         row["name"].to_s == "" ? row["login"] : row["name"],
         row["license_url"],
         row["copyright_holder"]]
      end
    end
  end
end
