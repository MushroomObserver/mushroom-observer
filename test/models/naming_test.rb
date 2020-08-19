# frozen_string_literal: true

require("test_helper")

class NamingTest < UnitTestCase
  # Propose a naming for an observation.
  def test_create
    assert_kind_of(Observation, observations(:coprinus_comatus_obs))
    now = Time.zone.now
    naming = Naming.new(
      created_at: now,
      updated_at: now,
      observation_id: observations(:coprinus_comatus_obs).id,
      name_id: names(:agaricus_campestris).id,
      user_id: mary.id
    )
    assert(naming.save, naming.errors.full_messages.join("; "))
  end

  # Change an existing one.
  def test_update
    assert_kind_of(Observation, observations(:coprinus_comatus_obs))
    assert_kind_of(Naming, namings(:coprinus_comatus_naming))
    assert_kind_of(Name, names(:coprinus_comatus))
    assert_kind_of(Name, names(:agaricus_campestris))
    assert_equal(names(:coprinus_comatus),
                 namings(:coprinus_comatus_naming).name)
    assert_equal(names(:coprinus_comatus),
                 observations(:coprinus_comatus_obs).name)

    namings(:coprinus_comatus_naming).updated_at = Time.zone.now
    namings(:coprinus_comatus_naming).name = names(:agaricus_campestris)
    assert(namings(:coprinus_comatus_naming).save)

    assert(namings(:coprinus_comatus_naming).errors.full_messages.join("; "))
    namings(:coprinus_comatus_naming).reload
    observations(:coprinus_comatus_obs).reload
    User.current = rolf
    observations(:coprinus_comatus_obs).calc_consensus
    assert_equal(names(:agaricus_campestris),
                 namings(:coprinus_comatus_naming).name)
    assert_equal(names(:agaricus_campestris),
                 observations(:coprinus_comatus_obs).name)
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
    assert_equal(names(:coprinus_comatus),
                 observations(:coprinus_comatus_obs).name)
    id = namings(:coprinus_comatus_naming).id
    User.current = rolf
    namings(:coprinus_comatus_naming).destroy
    observations(:coprinus_comatus_obs).reload
    observations(:coprinus_comatus_obs).calc_consensus
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(id) }
    assert_equal(names(:agaricus_campestris),
                 observations(:coprinus_comatus_obs).name)
  end

  def test_basic_reasons
    assert_nil(namings(:minimal_unknown_naming).reasons)

    assert_equal({ 1 => "Isn't it obvious?" },
                 namings(:coprinus_comatus_naming).reasons)

    assert_equal({ 1 => "", 2 => "I asked *Uncle Herb*" },
                 namings(:coprinus_comatus_other_naming).reasons)
  end

  def test_get_reasons
    nrs = namings(:minimal_unknown_naming).get_reasons
    assert_nil(nrs[0].notes)
    assert_nil(nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)

    nrs = namings(:coprinus_comatus_naming).get_reasons
    assert_equal("Isn't it obvious?", nrs[0].notes)
    assert_nil(nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)

    nrs = namings(:coprinus_comatus_other_naming).get_reasons
    assert_equal("", nrs[0].notes)
    assert_equal("I asked *Uncle Herb*", nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)
  end

  def test_get_reasons_hash
    nrs = namings(:minimal_unknown_naming).get_reasons_hash
    assert_nil(nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)

    nrs = namings(:coprinus_comatus_naming).get_reasons_hash
    assert_equal("Isn't it obvious?", nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)

    nrs = namings(:coprinus_comatus_other_naming).get_reasons_hash
    assert_equal("", nrs[1].notes)
    assert_equal("I asked *Uncle Herb*", nrs[2].notes)
    assert_nil(nrs[3].notes)
    assert_nil(nrs[4].notes)
  end

  def test_set_reasons
    naming = namings(:coprinus_comatus_other_naming)
    hash = {
      2 => nil,
      4 => "Well, how about \"this\"!!"
    }
    naming.set_reasons(hash)

    hash[2] = hash[2].to_s
    assert_equal(hash, naming.reasons)

    nrs = naming.get_reasons
    assert_nil(nrs[0].notes)
    assert_equal("", nrs[1].notes)
    assert_nil(nrs[2].notes)
    assert_equal("Well, how about \"this\"!!", nrs[3].notes)

    assert_equal(hash, naming.reasons)
  end

  def test_enforce_default_reasons
    naming = namings(:coprinus_comatus_other_naming)
    naming.set_reasons({})
    assert_equal({}, naming.reasons)
    naming.save!

    naming.reload
    assert_equal({ 1 => "" }, naming.reasons)
  end

  def test_reason_order
    naming = Naming.first
    assert_equal(Naming::Reason.all_reasons, naming.get_reasons.map(&:num))
    assert_equal(Naming::Reason.all_reasons,
                 naming.get_reasons.sort_by(&:order).map(&:num))
  end

  def test_reason_labels
    naming = Naming.first
    nrs = naming.get_reasons
    assert_equal("Recognized by sight", nrs.first.label.l)
    assert_equal("Based on chemical features", nrs.last.label.l)
  end

  def test_other_reason_methods
    naming = namings(:coprinus_comatus_other_naming)
    nrs = naming.get_reasons_hash

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
