# frozen_string_literal: true

"""
SELECT io.image_id
FROM images_observations io, observations o
WHERE o.name_id in (31753)
AND io.observation_id = o.id
AND o.vote_cache > 2.5;
"""

module Report
  module Darwin
    # Darwin Core Observations format.
    class TaxonImages < Report::CSV
      attr_accessor :taxa, :query

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.taxa = args[:taxa]
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
          licenses: License.arel_table,
          observations: Observation.arel_table,
          users: User.arel_table
        }
      end

      def add_joins
        join_table(:images_observations, :image_id, attribute(:images, :id))
        join_table(:observations, :id,
                   attribute(:images_observations, :observation_id))
        join_table(:licenses, :id, attribute(:images, :license_id))
        join_table(:users, :id, attribute(:images, :user_id))
      end

      def join_table(join_name, join_field, attribute)
        table = tables[join_name]
        join_attribute = table[join_field]
        self.query = query.join(table).on(join_attribute.eq(attribute))
      end

      def add_project
        query.project(attribute(:images, :id),
                      attribute(:observations, :name_id),
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
        names_attr = tables[:observations][:name_id]
        query.where(names_attr.in(taxa.ids))
        vote_cache_attr = tables[:observations][:vote_cache]
        query.where(vote_cache_attr.gt(2.5))

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
        [row["name_id"].to_s,
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
