#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
# One-time backfill of the project alert ledger.
#
# A row says a project has been told about an observation, and the
# first thing a project is told about one is that it was found. An
# observation a project already holds was surfaced to it when it was
# added, so a later change is activity on it rather than a find -- but
# nothing wrote a row for the observations added before the import did,
# so the next edit on iNaturalist, or the next naming here, reads as a
# new find and mails one.
#
# This writes the rows the collector would have written: one per
# observation a project holds that carries a name the project watches
# and sits in the places and dates it watches. Nothing is mailed, so
# the rows carry no alerted_at. Idempotent -- an observation the ledger
# already names is left alone.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/backfill_project_alerts.rb
# One project:
#   bin/rails runner script/backfill_project_alerts.rb --project=327
# Apply:
#   bin/rails runner script/backfill_project_alerts.rb --apply
# rubocop:enable MO/NoLongCommentBlock

APPLY = ARGV.delete("--apply") ? true : false
PROJECT_ID = ARGV.grep(/\A--project=\d+\z/).first&.delete_prefix("--project=")
ARGV.delete("--project=#{PROJECT_ID}") if PROJECT_ID
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner script/backfill_project_alerts.rb " \
       "[--project=<id>] [--apply]")
  exit(1)
end

# The ledger rows for the observations the projects already hold.
class ProjectAlertBackfill
  REPORT_EVERY = 200

  def initialize(apply:, project_id: nil)
    @apply = apply
    @project_id = project_id
    @counts = Hash.new(0)
    @excluded = {}
    @started = Time.zone.now
  end

  def run
    projects = scope.to_a
    warn("#{projects.size} project(s) watching names in places")
    projects.each { |project| backfill(project) }
    report
  end

  private

  def scope
    projects = Project.alertable.includes(:project_target_names,
                                          :project_target_locations)
    @project_id ? projects.where(id: @project_id) : projects
  end

  def backfill(project)
    rows = candidates(project)
    warn("project #{project.id} #{project.title}: #{rows.size} to write")
    rows.each_with_index do |obs, index|
      write(project, obs)
      progress(project, index + 1, rows.size)
    end
  end

  # The observations the collector would have written a row for: a name
  # this project watches, inside the places and dates it watches, and
  # nothing in the ledger yet.
  def candidates(project)
    held = held(project)
    @counts[:held] += held.size
    held.select { |obs| wanted?(project, obs) }
  end

  def held(project)
    name_ids = project.expanded_target_name_id_set.to_a
    return [] if name_ids.empty?

    project.observations.where(name_id: name_ids).order(:id).
      includes(:name, :location, external_links: :external_site).to_a
  end

  def wanted?(project, obs)
    reason = skipped(project, obs)
    return true unless reason

    @counts[reason] += 1
    false
  end

  def skipped(project, obs)
    return :outside_the_places_or_dates unless
      project.alert_matches_place?(obs)
    return :excluded_by_the_project if excluded(project).include?(obs.id)
    return :already_in_the_ledger if
      ProjectAlert.told_about(project, obs).exists?

    nil
  end

  def excluded(project)
    @excluded[project.id] ||= project.excluded_observations.pluck(:id).to_set
  end

  def write(project, obs)
    warn("  obs #{obs.id} #{obs.name.text_name}, observed " \
         "#{obs.when}#{remote_records(obs)}")
    return @counts[:would_write] += 1 unless @apply

    @counts[record(project, obs) ? :written : :already_in_the_ledger] += 1
  end

  # The row an import would have written, built here rather than
  # through ProjectAlert.record_local, which stamps alerted_at: these
  # rows mail nothing, and an empty column is how one says so.
  def record(project, obs)
    ProjectAlert.create!(
      project: project, observation: obs, target: obs,
      name: obs.name.text_name, target_name: obs.name.text_name,
      kind: ProjectAlert.local_kind_for(project, obs, obs),
      observed_on: obs.when
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # Where else the observation is, since the row being written decides
  # what the next edit there reads as.
  def remote_records(obs)
    records = obs.external_links.filter_map do |link|
      "#{link.external_site.name} #{link.external_id}" if
        link.external_id.present?
    end
    records.any? ? " (#{records.join(", ")})" : ""
  end

  def progress(project, done, total)
    return unless (done % REPORT_EVERY).zero?

    elapsed = (Time.zone.now - @started).round
    warn("  ... project #{project.id}: #{done}/#{total}, #{elapsed}s")
  end

  def report
    warn(@counts.map { |key, count| "#{key}: #{count}" }.join(", "))
    return if @apply

    warn("Dry run - nothing written. To apply: bin/rails runner " \
         "script/backfill_project_alerts.rb #{apply_args}")
  end

  def apply_args
    @project_id ? "--project=#{@project_id} --apply" : "--apply"
  end
end

ProjectAlertBackfill.new(apply: APPLY, project_id: PROJECT_ID).run
