# frozen_string_literal: true

# Contract release of the collector single-source migration (#4211 / PR #4452).
# Runs in the offline deploy window, AFTER the expand release added the column
# and script/backfill_collectors.rb seeded it online. Two steps:
#
#   1. SEED (safety net) — CollectorNotesSeeder fills any obs whose collector
#      column is still blank (rows the online backfill missed, or a notes
#      :Collector written during the expand window). Idempotent; normally a
#      near-no-op since the online backfill already ran.
#
#   2. STRIP — now that the column is the single source and the code no longer
#      reads notes for the collector, delete the canonical :Collector key from
#      notes and remove the forbidden "Collector" heading from notes_templates.
#      Variant keys / headings (e.g. "Collector's Name") are independent fields
#      and are left in place (#4211 decision C).
#
# Irreversible: stripped notes/template values cannot be reconstructed.
class MigrateCollectorNotes < ActiveRecord::Migration[7.2]
  COLLECTOR_KEY = :Collector
  BATCH_SIZE = 1_000

  def up
    CollectorNotesSeeder.new(reporter: self).run
    strip_collector_notes
    strip_user_templates
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end

  private

  # One transaction per batch: MySQL doesn't wrap the migration in a
  # transaction, so without this each update_columns auto-commits per row.
  def strip_collector_notes
    scope = Observation.where("notes LIKE ?", "%Collector%")
    say("Strip notes: scanning #{scope.count} obs")
    stripped = 0
    scope.in_batches(of: BATCH_SIZE) do |batch|
      Observation.transaction { stripped += strip_batch(batch) }
    end
    say("Stripped :Collector from #{stripped} obs", true)
  end

  def strip_batch(batch)
    stripped = 0
    batch.each do |obs|
      next unless obs.notes.key?(COLLECTOR_KEY)

      obs.update_columns(notes: obs.notes.except(COLLECTOR_KEY))
      stripped += 1
    end
    stripped
  end

  def strip_user_templates
    scope = User.where("notes_template LIKE ?", "%Collector%")
    say("Strip templates: scanning #{scope.count} users")
    changed = 0
    scope.find_each do |user|
      kept = template_without_collector(user)
      next unless kept

      user.update_column(:notes_template, kept)
      changed += 1
    end
    say("Stripped 'Collector' from #{changed} templates", true)
  end

  # The notes_template without the exact "Collector" heading, or nil when it
  # has no such heading (variants like "Collector's Name" are left in place).
  def template_without_collector(user)
    parts = user.notes_template.to_s.split(",").map(&:squish)
    return unless parts.include?("Collector")

    parts.reject { |part| part == "Collector" }.join(", ")
  end
end
