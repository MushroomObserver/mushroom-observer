# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("db/migrate/20260602000001_migrate_collector_notes.rb").to_s)

# Exercises the #4211 collector-seeding policy (PR #4452): which legacy
# notes values become a linked collector, a free-text collector, or are
# skipped. The migrator delegates resolution to Observation.resolve_collector
# (covered in observation_test.rb); these tests pin the per-key policy and
# the fuzzy owner-name match.
class MigrateCollectorNotesTest < UnitTestCase
  # The migrator only needs an object that responds to #say for progress.
  class SilentMigration
    def say(*); end
  end

  def migrator
    @migrator ||=
      MigrateCollectorNotes::CollectorNotesMigrator.new(SilentMigration.new)
  end

  # Create an obs with the given notes and a blank collector column, the
  # state the migration's seed pass scans for.
  def obs_with_notes(notes, user: mary)
    obs = Observation.create!(user: user, when: Time.zone.now,
                              where: "Anywhere", name: names(:fungi))
    obs.update_columns(collector: nil, collector_user_id: nil, notes: notes)
    obs
  end

  def seed(obs)
    migrator.send(:seed, obs.reload)
    obs.reload
  end

  # --- name-variant key: single real person kept as free text ---

  def test_seed_name_variant_keeps_single_person_free_text
    obs = seed(obs_with_notes({ "Collector's_Name": "Bill Sheehan" }))
    assert_equal("Bill Sheehan", obs.collector)
    assert_nil(obs.collector_user_id)
  end

  # --- name-variant key: reformatted owner name links to the owner ---

  def test_seed_name_variant_fuzzy_owner_match_links_owner
    obs = seed(obs_with_notes({ "Collector's_Name": "Rolf C. Singer" },
                              user: rolf))
    assert_equal(rolf.id, obs.collector_user_id)
    assert_equal(rolf.unique_text_name, obs.collector)
  end

  # --- name-variant key: lists / junk / long sentences are skipped ---

  def test_seed_name_variant_skips_list_junk_and_sentence
    [{ "Collector's_Name": "D. Newman & R. Vandegrift" },
     { "Collector's_Name": "N/A" },
     { "Collector's_Name": "Likely new species of Clitocybe based on a " \
                              "DNA barcode of similar collections" }].each do |n|
      obs = seed(obs_with_notes(n))
      assert_nil(obs.collector, "should skip #{n.values.first.inspect}")
      assert_nil(obs.collector_user_id)
    end
  end

  # --- "Collector(s)" is user-only: links when resolvable, else skipped ---

  def test_seed_collectors_key_links_resolvable_user
    obs = seed(obs_with_notes({ "Collector(s)": rolf.login }, user: mary))
    assert_equal(rolf.id, obs.collector_user_id)
  end

  def test_seed_collectors_key_skips_unresolvable_free_text
    obs = seed(obs_with_notes({ "Collector(s)": "Gerry Ansell" },
                              user: mary))
    assert_nil(obs.collector)
    assert_nil(obs.collector_user_id)
  end

  # --- canonical :Collector seeds even non-person free text ---

  def test_seed_canonical_collector_keeps_free_text
    obs = seed(obs_with_notes({ Collector: "N/A" }))
    assert_equal("N/A", obs.collector)
    assert_nil(obs.collector_user_id)
  end

  def test_seed_canonical_collector_markup_links_user
    obs = seed(obs_with_notes({ Collector: "_user rolf_" }, user: mary))
    assert_equal(rolf.id, obs.collector_user_id)
    assert_equal(rolf.unique_text_name, obs.collector)
  end

  # --- the lowercase :collector key is not a seed source ---

  def test_seed_ignores_lowercase_collector_key
    obs = seed(obs_with_notes({ collector: "my collectors" }))
    assert_nil(obs.collector)
  end
end
