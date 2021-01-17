# frozen_string_literal: true

module Report
  module Darwin
    # Darwin Core Observations format.
    class TaxonImages < Report::CSV
      VOTE_CUTOFF = 2.5

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
        query.where(tables[:observations][:vote_cache].gteq(VOTE_CUTOFF))
        query.where(tables[:images][:ok_for_export].eq(1))
        add_name_conditions(tables[:names])
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
                      attribute(:names, :text_name),
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
        @formatted_rows = sort_after(rows.map { |row| format_image_row(row) })
      end

      def rows
        @rows ||= ActiveRecord::Base.connection.exec_query(query.to_sql)
      end

      def taxa
        return @taxa if @taxa

        @taxa = Set.new
        rows.each { |row| @taxa.add([row["name_id"], row["text_name"]]) }
        @taxa
      end

      def labels
        %w[
          imageURL
          name
          nameURL
        ]
      end

      def sort_after(rows)
        rows.sample(100)
      end

      private

      def image_url(id)
        "https://mushroomobserver.org/images/640/#{id}.jpg"
      end

      def name_url(id)
        "https://mushroomobserver.org/name/show_name/#{id}"
      end

      def format_image_row(row)
        [image_url(row["id"]),
         row["text_name"].to_s,
         name_url(row["name_id"]).to_s]
      end
    end
  end
end
