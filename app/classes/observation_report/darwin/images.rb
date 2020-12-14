# frozen_string_literal: true

module ObservationReport
  module Darwin
    # Darwin Core Observations format.
    class Images < ObservationReport::CSV
      attr_accessor :observations, :query

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.observations = args[:observations]
        initialize_query
      end

      def initialize_query
        self.query = tables[:images]
        add_joins
        add_project
      end

      def tables
        @tables ||= {
          images: Image.arel_table,
          images_observations: Arel::Table.new(:images_observations),
          users: User.arel_table,
          licenses: License.arel_table
        }
      end

      def add_joins
        join_table(:images_observations, :image_id, attribute(:images, :id))
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
                      attribute(:images_observations,
                                :observation_id).as("obs_id"),
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
        obs_attr = tables[:images_observations][:observation_id]
        query.where(obs_attr.in(observations.ids))
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

      def sort_after(rows)
        rows.sort_by { |row| row[0].to_i }
      end

      private

      def image_url(id)
        "https://mushroomobserver.org/images/320/#{id}.jpg"
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
