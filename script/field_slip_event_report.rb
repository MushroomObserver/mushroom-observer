#!/usr/bin/env ruby
# frozen_string_literal: true

# Post-event cleanup report for a field-slip project: everything the
# collectors got wrong that an admin should review after the event,
# so bad data becomes a review queue instead of an event-time problem.
#
#   bin/rails runner script/field_slip_event_report.rb PROJECT_ID
#
# Read-only. Sections:
#   - observations whose GPS is dubious for their named location
#   - observations with a free-text locality (no Location record)
#   - observations with no GPS at all
#   - iNaturalist notes that never resolved to a link (raw text)
#   - slips in the project with no observation attached
class FieldSlipEventReport
  USAGE = "Usage: bin/rails runner " \
          "script/field_slip_event_report.rb PROJECT_ID"

  def self.from_argv(argv)
    abort(USAGE) unless argv.size == 1 && argv.first.match?(/\A\d+\z/)

    project = Project.find_by(id: argv.first)
    abort("No project with id #{argv.first}") unless project
    new(project)
  end

  def initialize(project)
    @project = project
    @observations = project.observations.
                    includes(:location, :projects,
                             occurrence: :field_slip).to_a
  end

  def run
    puts("Cleanup report for project #{@project.id} (#{@project.title})")
    puts("#{@observations.size} observations")
    report_dubious_gps
    report_free_text_localities
    report_missing_gps
    report_unlinked_inat_notes
    report_empty_slips
    report_cross_prefix_observations
  end

  private

  def obs_url(obs)
    "https://mushroomobserver.org/obs/#{obs.id}"
  end

  def section(title, rows)
    puts("\n== #{title}: #{rows.size}")
    rows.each { |row| puts("  #{row}") }
  end

  # GPS more than Observation::DUBIOUS_GPS_KM from the named location:
  # one of them is wrong, and only a human can say which.
  def report_dubious_gps
    rows = @observations.select(&:lat_lng_dubious?).map do |obs|
      "#{obs_url(obs)}  #{obs.lat},#{obs.lng} vs #{obs.where}"
    end
    section("GPS dubious for the named location", rows)
  end

  def report_free_text_localities
    rows = @observations.select { |o| o.location_id.nil? }.
           group_by(&:where).sort_by { |_, v| -v.size }.
           map do |where, obs|
             "#{where.inspect} (#{obs.size}): " +
               obs.map { |o| obs_url(o) }.join(" ")
           end
    section("free-text localities (no Location record)", rows)
  end

  def report_missing_gps
    rows = @observations.select { |o| o.lat.nil? }.map { |o| obs_url(o) }
    section("no GPS at all", rows)
  end

  # An iNaturalist note that is not the canonical link -- a username,
  # a mangled id, or an id the review left unticked.
  def report_unlinked_inat_notes
    rows = @observations.filter_map do |obs|
      note = obs.notes.to_h[:iNaturalist]
      next if note.blank? || FieldSlipNotesBuilder.inat_link?(note.to_s)
      next if linked_to_inat?(note.to_s)

      "#{obs_url(obs)}  #{note.to_s[0, 60].inspect}"
    end
    section("iNaturalist notes without a link", rows)
  end

  # A hand-pasted iNat URL counts as linked too, not just our canonical
  # shape. Each URL's host is compared exactly -- a substring test would
  # accept an unrelated URL that merely embeds iNat's address.
  def linked_to_inat?(text)
    text.scan(%r{https?://\S+}).any? do |candidate|
      URI.parse(candidate).host&.casecmp?("www.inaturalist.org")
    rescue URI::InvalidURIError
      false
    end
  end

  def report_empty_slips
    rows = FieldSlip.where(project: @project).includes(:occurrence).
           select { |slip| slip.occurrence.nil? }.
           map { |slip| "#{slip.code}  (field slip #{slip.id})" }
    section("slips with no observation", rows)
  end

  # This project's observations that ALSO sit in other prefix-bearing
  # projects -- usually a pre-checked leftover from another event,
  # occasionally deliberate (a fair's observations also collected into
  # the herbarium project behind it). The form warns on the typed-code
  # path; the photo-first path only learns its slip's project after
  # create, so it shows up here instead.
  def report_cross_prefix_observations
    rows = @observations.filter_map do |obs|
      others = obs.projects.select do |proj|
        proj.id != @project.id && proj.field_slip_prefix.present?
      end
      next if others.empty?

      "#{obs_url(obs)}  also in: #{others.map(&:title).join("; ")}"
    end
    section("also in other field-slip projects", rows)
  end
end

FieldSlipEventReport.from_argv(ARGV).run
