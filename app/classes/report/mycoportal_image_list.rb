# frozen_string_literal: true

# List of image URLa for updating the images in MO's MyCoPortal database
# via MyCoPortal's Occurence Management, Observation Project Management,
#    Administration Control Panel. Processing Toolbox
# MCP expects a CSV with one row per image and 2 columns: catalogNumber, imageId
module Report
  class MycoportalImageList < CSV
    attr_accessor :query

    # This URL prefix is permanent for large images, should always be correct,
    # no matter how much we change the underlying image server(s).
    # It should be the same in all environments, so that we can use the dev
    # environment for MyCoPortal uploads.
    LARGE_IMG_PERMALINK_PREFIX = "https://mushroomobserver.org/images/1280/"

    def initialize(query)
      super
      @query = query[:query]
    end

    # --------------------
    # Things expected by Observation::DownloadsController#render_report.

    def body
      image_list
    end

    def mime_type
      "text/csv"
    end

    def encoding
      "UTF-8"
    end

    def filename
      "mycoportal_image_list_#{@query.id&.alphabetize}.csv"
    end

    def header
      { header: :present }
    end

    # --------------------

    private

    def image_list
      rows_data =
        Image.joins(:observations).
        where(observations: { id: @query.result_ids }).
        # MCP doesn't care about order, but our tests do.
        order(observation_id: :asc, id: :asc).
        pluck(:observation_id, :id)

      ::CSV.generate(col_sep: ",", encoding: "UTF-8") do |csv|
        csv << %w[catalogNumber imageId]
        rows_data.each do |row|
          csv << formatted_row(row)
        end
      end
    end

    def formatted_row(row)
      [catalog_number(row.first), large_image_url(row.last)]
    end

    def catalog_number(observation_id)
      "MUOB #{observation_id}"
    end

    def large_image_url(image_id)
      "#{LARGE_IMG_PERMALINK_PREFIX}#{image_id}.jpg"
    end
  end
end
