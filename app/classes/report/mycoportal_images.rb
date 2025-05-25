# frozen_string_literal: true

require "haversine"

# TSV spreadsheet for uploading images to MyCoPortal
module Report
  class MycoportalImages < TSV
    # http_domain for links to Observations and Images
    HTTP_DOMAIN = "https://mushroomobserver.org"

    # Label names for the columns in the report.
    def labels
      [
        "catalogNumber", # "MUOB" + space + observation.id"
        "imageUrls" # list of image urls; not a Symbiota or MCP field
      ]
    end

    # content of the report rows
    def format_row(row)
      [
        "MUOB #{row.obs_id}", # catalogNumber
        image_urls(row) # list of large-size image urls
      ]
    end

    def image_urls(row)
      row.val(1).to_s.split(", ").sort_by(&:to_i).
        map { |id| image_url(id) }.join(" ")
    end

    ####### Additional columns and utilities

    # extended data used to calculate some values
    # See app/classes/report/base_table.rb
    def extend_data!(rows)
      add_image_ids!(rows, 1)
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    ##########

    private

    def image_url(id)
      # This URL is permanent. It should always be correct,
      # no matter how much we change the underlying image server(s).
      # It is large, rather than full-size, because we no longer
      # let anonymous users access full-size images because of
      # bot/scraper issues
      "#{HTTP_DOMAIN}/images/1280/#{id}.jpg" if id.present?
    end
  end
end
