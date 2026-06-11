# frozen_string_literal: true

require("test_helper")
require(Rails.root.join(
  "db/migrate/20260611000000_migrate_collector_notes.rb"
).to_s)

# The contract migration's strip passes (#4211 / PR #4452). Seeding itself is
# covered in collector_notes_seeder_test.rb; here we pin that the migration
# strips the canonical :Collector note + the "Collector" template heading while
# leaving the column, variant keys, and other notes intact.
class MigrateCollectorNotesTest < UnitTestCase
  # Silence the migration's `say` progress output (and the seeder's, which
  # reports through the migration) so the test run stays readable.
  def setup
    super
    @prior_migration_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    ActiveRecord::Migration.verbose = @prior_migration_verbose
    super
  end

  def migration
    @migration ||= MigrateCollectorNotes.new
  end

  def obs_with_notes(notes, collector: nil)
    obs = Observation.create!(user: mary, when: Time.zone.now,
                              where: "Anywhere", name: names(:fungi))
    obs.update_columns(collector: collector, collector_user_id: nil,
                       notes: notes)
    obs
  end

  def test_strip_removes_collector_note_keeps_column_and_variants
    obs = obs_with_notes(
      { Collector: "_user rolf_", "Collector's_Name": "Bill", Other: "x" },
      collector: "Rolf Singer (rolf)"
    )

    migration.send(:strip_collector_notes)
    obs.reload

    assert_not(obs.notes.key?(:Collector), "canonical :Collector stripped")
    assert_equal("Bill", obs.notes[:"Collector's_Name"], "variant kept")
    assert_equal("x", obs.notes[:Other], "other notes kept")
    assert_equal("Rolf Singer (rolf)", obs.collector, "column untouched")
  end

  def test_strip_removes_collector_template_heading_keeps_variants
    user = users(:rolf)
    user.update_column(:notes_template, "Cap, Collector, Collector's Name")

    migration.send(:strip_user_templates)

    assert_equal("Cap, Collector's Name", user.reload.notes_template)
  end

  # The migration seeds before stripping, so a row whose column was never
  # backfilled still keeps its collector (in the column) after the note goes.
  def test_up_seeds_then_strips
    obs = obs_with_notes({ Collector: "_user rolf_" }, collector: nil)

    migration.up
    obs.reload

    assert_equal(rolf.id, obs.collector_user_id, "safety-seeded from note")
    assert_not(obs.notes.key?(:Collector), "then stripped")
  end
end
