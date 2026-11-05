# frozen_string_literal: true

# Generate the MyCoPortal (MCP) data + image CSVs for observations
# to export/update. Writes
# both CSVs to disk and alerts #alerts with their paths, since (unlike
# the admin download form) there's no HTTP request to stream them into.
#
# USAGE:
# From a Rails console:
#   MycoportalExportJob.perform_now or
#   MycoportalExportJob.perform_later
# (Not yet wired to a schedule.)
class MycoportalExportJob < ApplicationJob
  queue_as(:maintenance)

  EXPORT_DIR = Rails.root.join("tmp/mycoportal")

  def perform
    ids = observation_ids
    return log("MyCoPortal export: no observations to export") if ids.empty?

    query = Query.lookup(:Observation, id_in_set: ids)
    data_path = write_report(Report::Mycoportal.new(query: query,
                                                    user: User.admin),
                             "mycoportal_data")
    images_path = write_report(Report::MycoportalImageList.new(query: query),
                               "mycoportal_images")

    alert("MyCoPortal export ready: #{ids.size} observation(s) -> " \
          "#{data_path}, #{images_path}")
  end

  private

  def observation_ids
    candidates = Mycoportal::ExportCandidates.new
    candidates.updated_observation_ids + candidates.new_observation_ids
  end

  def write_report(report, basename)
    body = report.body
    report.mark_exported! if report.respond_to?(:mark_exported!)
    path = export_path(basename)
    File.write(path, body)
    path
  end

  def export_path(basename)
    FileUtils.mkdir_p(EXPORT_DIR)
    EXPORT_DIR.join("#{basename}_#{Time.zone.today.iso8601}.csv")
  end
end
