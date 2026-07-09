# frozen_string_literal: true

require("test_helper")

class InatPhotoHashTest < UnitTestCase
  def test_valid
    record = InatPhotoHash.new(inat_photo_id: 42, dhash: 123,
                               fetched_at: Time.current)

    assert(record.valid?)
  end

  def test_requires_fields
    record = InatPhotoHash.new

    assert_not(record.valid?)
    assert_includes(record.errors.attribute_names, :inat_photo_id)
    assert_includes(record.errors.attribute_names, :dhash)
    assert_includes(record.errors.attribute_names, :fetched_at)
  end

  def test_inat_photo_id_unique
    InatPhotoHash.create!(inat_photo_id: 7, dhash: 1, fetched_at: Time.current)
    dup = InatPhotoHash.new(inat_photo_id: 7, dhash: 2,
                            fetched_at: Time.current)

    assert_not(dup.valid?)
    assert_includes(dup.errors.attribute_names, :inat_photo_id)
  end
end
