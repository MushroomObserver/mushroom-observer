require File.dirname(__FILE__) + '/../boot'

class NamingReasonTest < Test::Unit::TestCase

  # Create one.
  def test_create
    assert_kind_of Naming, namings(:coprinus_comatus_naming)
    nr = NamingReason.new(
        :naming => namings(:coprinus_comatus_naming),
        :reason => 2,
        :notes  => "Arora"
    )
    assert nr.save, nr.errors.full_messages.join("; ")
  end

  # Change an existing one.
  def test_update
    assert_kind_of Naming, namings(:coprinus_comatus_naming)
    assert_kind_of NamingReason, naming_reasons(:cc_macro_reason)
    naming_reasons(:cc_macro_reason).notes = "No way!"
    assert naming_reasons(:cc_macro_reason).save
    assert naming_reasons(:cc_macro_reason).errors.full_messages.join("; ")
    naming_reasons(:cc_macro_reason).reload
    assert_equal "No way!", naming_reasons(:cc_macro_reason).notes
  end

  # Make sure it fails if we screw up.
  def test_validate
    nr = NamingReason.new()
    assert !nr.save
    assert_equal 2, nr.errors.count
    assert_equal :validate_naming_reason_naming_missing.t, nr.errors.on(:naming)
    assert_equal :validate_naming_reason_reason_invalid.t, nr.errors.on(:reason)
    nr = NamingReason.new(
        :naming => namings(:coprinus_comatus_naming),
        :reason => 999
    )
    assert !nr.save
    assert_equal 1, nr.errors.count
    assert_equal :validate_naming_reason_reason_invalid.t, nr.errors.on(:reason)
  end

  # Destroy one.
  def test_destroy
    id = naming_reasons(:cc_macro_reason).id
    naming_reasons(:cc_macro_reason).destroy
    assert_raise(ActiveRecord::RecordNotFound) { NamingReason.find(id) }
  end
end
