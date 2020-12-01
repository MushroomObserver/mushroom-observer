# frozen_string_literal: true

module ObservationReport
  module Darwin
    # Darwin Core Observations format.
    class Images < ObservationReport::CSV
      attr_accessor :observations, :query, :tables

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.observations = args[:observations]
        initialize_query
      end

      def initialize_query
        add_joins
        add_project
      end

      def add_joins
        self.tables = {
          images: Image.arel_table,
          images_observations: Arel::Table.new(:images_observations),
          observations: Observation.arel_table,
          users: User.arel_table,
          licenses: License.arel_table
        }
        self.query = tables[:images]
        join_table(:images_observations, :image_id, attribute(:images, :id))
        io_attribute = attribute(:images_observations, :observation_id)
        join_table(:observations, :id, io_attribute)
        join_table(:users, :id, attribute(:images, :user_id))
        join_table(:licenses, :id, attribute(:images, :license_id))
      end

      def join_table(join_name, join_field, attribute)
        table = tables[join_name]
        join_attribute = table[join_field]
        self.query = query.join(table).on(join_attribute.eq(attribute))
      end

      def add_project
        query.project(attribute(:images, :id),
                      attribute(:observations, :id).as("obs_id"),
                      attribute(:images, :when),
                      attribute(:users, :name),
                      attribute(:users, :login),
                      attribute(:licenses, :url).as("license_url"),
                      attribute(:images, :copyright_holder))
      end

      def attribute(table_name, field)
        tables[table_name][field]
      end

      def formatted_rows
        query.where(tables[:observations][:id].in(observations.ids))
        rows = ActiveRecord::Base.connection.exec_query(query.to_sql)
        sort_after(rows.map { |row| format_image_row(row) })
      end

      def labels
        %w[
          identifier
          type
          format
          accessURL
          created
          creator
          license
          rightsHolder
        ]
      end

      def format_row(row)
        row
      end

      def sort_after(rows)
        rows.sort_by { |row| row[0].to_i }
      end

      private

      def image_url(id)
        "https://images.mushroomobserver.org/1280/#{id}.jpg"
      end

      def format_image_row(row)
        [row["obs_id"].to_s,
         "StillImage",
         "image/jpeg",
         image_url(row["id"]),
         row["when"].to_s,
         row["name"].to_s == "" ? row["login"] : row["name"],
         row["license_url"],
         row["copyright_holder"]]
      end
    end
  end
end
