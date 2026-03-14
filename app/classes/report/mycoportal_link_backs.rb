# frozen_string_literal: true

# Report (a CSV) for uploading linkbacks to MyCoPortal (MCP).
# Use this to add URLs for Observation pages in MO to records in MCP.
# Upload in MyCoPortal's Occurrence Management,
#   Observation Project Management, Administration Control Panel,
#   Processing Toolbox
# MCP expects a CSV with one row per observation and 2 columns:
#   subjectCatalogNumber, resourceUrl
module Report
  class MycoportalLinkBacks < CSV
    def labels
      %w[subjectCatalogNumber resourceUrl]
    end

    def format_row(row)
      [
        "MUOB #{row.obs_id}", # subjectCatalogNumber
        resource_url(row)     # resourceUrl
      ]
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    private

    def resource_url(row)
      "#{MO.http_domain}/obs/#{row.obs_id}"
    end
  end
end
