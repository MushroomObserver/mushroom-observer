# frozen_string_literal: true

require("test_helper")

class NamingTest < UnitTestCase
  # Propose a naming for an observation.
  def test_create
    obs = observations(:coprinus_comatus_obs)
    assert_kind_of(Observation, obs)
    now = Time.zone.now
    naming = Naming.new(
      created_at: now,
      updated_at: now,
      observation_id: obs.id,
      name_id: names(:agaricus_campestris).id,
      user_id: mary.id
    )
    assert(naming.save, naming.errors.full_messages.join("; "))
  end

  # Change an existing one.
  def test_update
    obs = observations(:coprinus_comatus_obs)
    ncc = namings(:coprinus_comatus_naming)
    assert_kind_of(Observation, obs)
    assert_kind_of(Naming, ncc)
    assert_kind_of(Name, names(:coprinus_comatus))
    assert_kind_of(Name, names(:agaricus_campestris))
    assert_equal(names(:coprinus_comatus), ncc.name)
    assert_equal(names(:coprinus_comatus), obs.name)

    ncc.updated_at = Time.zone.now
    ncc.name = names(:agaricus_campestris)
    assert(ncc.save)

    assert(ncc.errors.full_messages.join("; "))
    User.current = rolf
    consensus = Observation::NamingConsensus.new(obs)
    consensus.calc_consensus
    assert_equal(names(:agaricus_campestris), ncc.reload.name)
    assert_equal(names(:agaricus_campestris), obs.reload.name)
  end

  # Make sure it fails if we screw up.
  def test_validate
    naming = Naming.new
    assert_not(naming.save)
    assert_equal(3, naming.errors.count)
    assert_equal(:validate_naming_name_missing.t, naming.errors[:name].first)
    assert_equal(:validate_naming_observation_missing.t,
                 naming.errors[:observation].first)
    assert_equal(:validate_naming_user_missing.t, naming.errors[:user].first)
  end

  # Destroy one.
  def test_destroy
    obs = observations(:coprinus_comatus_obs)
    assert_equal(names(:coprinus_comatus), obs.name)
    id = namings(:coprinus_comatus_naming).id
    User.current = rolf
    namings(:coprinus_comatus_naming).destroy
    obs.reload
    consensus = Observation::NamingConsensus.new(obs)
    consensus.calc_consensus
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(id) }
    assert_equal(names(:agaricus_campestris), obs.name)
  end

  def test_basic_reasons
    assert_nil(namings(:minimal_unknown_naming).reasons)

    assert_equal({ 1 => "Isn't it obvious?" },
                 namings(:coprinus_comatus_naming).reasons)

    assert_equal({ 1 => "", 2 => "I asked *Uncle Herb*" },
                 namings(:coprinus_comatus_other_naming).reasons)
  end

  def test_reasons_array
    nrs = namings(:minimal_unknown_naming).reasons_array
    assert_nil(nrs[0].notes)
    assert_nil(nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)

    nrs = namings(:coprinus_comatus_naming).reasons_array
    assert_equal("Isn't it obvious?", nrs[0].notes)
    assert_nil(nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)

    nrs = namings(:coprinus_comatus_other_naming).reasons_array
    assert_equal("", nrs[0].notes)
    assert_equal("I asked *Uncle Herb*", nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)
  end

  def test_reasons_hash
    nrs = namings(:minimal_unknown_naming).reasons_hash
    assert_nil(nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)

    nrs = namings(:coprinus_comatus_naming).reasons_hash
    assert_equal("Isn't it obvious?", nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)

    nrs = namings(:coprinus_comatus_other_naming).reasons_hash
    assert_equal("", nrs[1].notes)
    assert_equal("I asked *Uncle Herb*", nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)
  end

  def test_update_reasons
    naming = namings(:coprinus_comatus_other_naming)
    hash = {
      2 => nil,
      4 => "Well, how about \"this\"!!"
    }
    naming.update_reasons(hash)

    hash[2] = hash[2].to_s
    assert_equal(hash, naming.reasons)

    nrs = naming.reasons_array
    assert_nil(nrs[0].notes)
    assert_equal("", nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_equal("Well, how about \"this\"!!", nrs[3].notes)

    assert_equal(hash, naming.reasons)
  end

  def test_enforce_default_reasons
    naming = namings(:coprinus_comatus_other_naming)
    naming.update_reasons({})
    assert_equal({}, naming.reasons)
    naming.save!

    naming.reload
    assert_equal({ 1 => "" }, naming.reasons)
  end

  def test_reason_order
    naming = Naming.first
    assert_equal(Naming::Reason.all_reasons, naming.reasons_array.map(&:num))
    assert_equal(Naming::Reason.all_reasons,
                 naming.reasons_array.sort_by(&:order).map(&:num))
  end

  def test_reason_labels
    naming = Naming.first
    nrs = naming.reasons_array
    assert_equal("Recognized by sight", nrs.first.label.l)
    assert_equal("Based on chemical features", nrs.last.label.l)
  end

  def test_other_reason_methods
    naming = namings(:coprinus_comatus_other_naming)
    nrs = naming.reasons_hash

    assert(nrs[1].used?)
    assert(nrs[2].used?)
    assert_not(nrs[3].used?)
    assert_not(nrs[4].used?)

    assert_equal("", nrs[1].notes)
    assert_equal("I asked *Uncle Herb*", nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)

    nrs[3].notes = "test"
    nrs[2].notes = nil
    nrs[1].delete
    assert_equal({ 2 => "", 3 => "test" }, naming.reasons)
  end
end
