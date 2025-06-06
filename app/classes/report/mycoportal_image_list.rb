# frozen_string_literal: true

# List of image URLa for updating the images in MO's MyCoPortal database
# via MyCoPortal's Occurence Management, Observation Project Management,
#    Administration Control Panel. Processing Toolbox
# MCP expects a CSV with one row per image and 2 columns: catalogNumber, imageId
module Report
  class MycoportalImageList < CSV
    attr_accessor :query

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
      "https://images.mushroomobserver.org/1280/#{image_id}.jpg"
    end
  end
end
