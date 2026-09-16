# frozen_string_literal: true

require("test_helper")

class CopyrightChangeTest < UnitTestCase
  def valid_attributes
    {
      user: users(:rolf),
      target: images(:in_situ_image),
      updated_at: Time.zone.now,
      license: licenses(:ccby),
      year: 2020,
      name: "Rolf Singer"
    }
  end

  def test_valid_with_all_required_attributes
    cc = CopyrightChange.new(valid_attributes)
    assert(cc.valid?)
  end

  def test_invalid_without_user
    cc = CopyrightChange.new(valid_attributes.merge(user: nil))
    assert_not(cc.valid?)
  end

  def test_invalid_without_target
    cc = CopyrightChange.new(valid_attributes.merge(target: nil))
    assert_not(cc.valid?)
  end

  def test_invalid_without_updated_at
    cc = CopyrightChange.new(valid_attributes.merge(updated_at: nil))
    assert_not(cc.valid?)
  end

  def test_invalid_without_license
    cc = CopyrightChange.new(valid_attributes.merge(license: nil))
    assert_not(cc.valid?)
  end
end
