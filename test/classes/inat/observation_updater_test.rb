# frozen_string_literal: true

require("test_helper")

class Inat
  class ObservationUpdaterTest < UnitTestCase
    def test_statistics_initialization
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)

      updater = ObservationUpdater.new([obs], user)

      assert_equal(0, updater.stats.observations_processed)
      assert_equal(0, updater.stats.namings_added)
      assert_equal(0, updater.stats.provisional_names_added)
      assert_equal(0, updater.stats.sequences_added)
      assert_equal(0, updater.stats.error_count)
    end

    def test_process_identification_with_existing_name
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # Create an iNat identification with a taxon that exists in MO
      name = names(:coprinus_comatus)
      ident = {
        taxon: { name: name.text_name, rank: "species" },
        user: { login: "test_user" },
        created_at_details: { date: "2024-01-15" }
      }

      initial_naming_count = obs.namings.count
      updater.send(:process_identification, obs, ident)

      assert_equal(initial_naming_count + 1, obs.namings.reload.count)
      assert_equal(1, updater.stats.namings_added)
    end

    def test_process_identification_skips_unknown_name
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # Create an iNat identification with a taxon that doesn't exist in MO
      ident = {
        taxon: { name: "Nonexistent mushroom", rank: "species" },
        user: { login: "test_user" },
        created_at_details: { date: "2024-01-15" }
      }

      initial_naming_count = obs.namings.count
      updater.send(:process_identification, obs, ident)

      # Should not add a naming for unknown names
      assert_equal(initial_naming_count, obs.namings.reload.count)
      assert_equal(0, updater.stats.namings_added)
    end

    def test_name_already_proposed_returns_true_when_proposed
      obs = observations(:coprinus_comatus_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # This observation already has a naming for coprinus_comatus
      name = names(:coprinus_comatus)
      result = updater.send(:name_already_proposed?, obs, name)

      assert(result)
    end

    def test_name_already_proposed_returns_false_when_not_proposed
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # This observation has no namings
      name = names(:coprinus_comatus)
      result = updater.send(:name_already_proposed?, obs, name)

      assert_not(result)
    end

    def test_build_naming_creates_naming_with_correct_attributes
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      name = names(:agaricus_campestris)
      ident = {
        user: { login: "test_user" },
        created_at_details: { date: "2024-01-15" }
      }

      naming = updater.send(:build_naming, obs, name, ident)

      assert_equal(obs.id, naming.observation_id)
      assert_equal(name.id, naming.name_id)
      assert_equal(user.id, naming.user_id)

      # Reasons is a Hash (serialized automatically by Naming model)
      assert_match(/test_user/, naming.reasons[1])
      assert_match(/2024-01-15/, naming.reasons[1])
    end

    def test_build_sequence_creates_sequence_with_correct_attributes
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      locus = "ITS"
      bases = "ACGTACGT"

      sequence = updater.send(:build_sequence, obs, locus, bases)

      assert_equal(obs, sequence.observation)
      assert_equal(user, sequence.user)
      assert_equal(locus, sequence.locus)
      assert_equal(bases, sequence.bases)
      assert_equal("", sequence.archive)
      assert_equal("", sequence.accession)
      assert_match(/Imported from iNat/, sequence.notes)
    end

    def test_sequence_already_exists_returns_true_for_duplicate
      obs = observations(:genbanked_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # This observation has a sequence with locus "LSU"
      seq = obs.sequences.first
      result = updater.send(
        :sequence_already_exists?,
        obs,
        seq.locus,
        seq.bases
      )

      assert(result)
    end

    def test_sequence_already_exists_returns_false_for_new_sequence
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # This observation has no sequences
      result = updater.send(
        :sequence_already_exists?,
        obs,
        "ITS",
        "ACGTACGT"
      )

      assert_not(result)
    end

    def test_provisional_name_in_notes_returns_true_when_present
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      # Add provisional name to notes
      obs.notes = { Other: "Some text\n\nProvisional name: Test species" }

      result = updater.send(:provisional_name_in_notes?, obs, "Test species")

      assert(result)
    end

    def test_provisional_name_in_notes_returns_false_when_absent
      obs = observations(:minimal_unknown_obs)
      user = users(:rolf)
      updater = ObservationUpdater.new([obs], user)

      obs.notes = { Other: "Some other text" }

      result = updater.send(:provisional_name_in_notes?, obs, "Test species")

      assert_not(result)
    end
  end
end
