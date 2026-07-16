# frozen_string_literal: true

require("test_helper")

class ImageGapCheckpointTest < UnitTestCase
  # An uninitialized checkpoint defaults to the current max image id, so a
  # scheduled run examines nothing (safe) until it is explicitly seeded.
  def test_defaults_to_max_image_id
    ImageGapCheckpoint.delete_all
    assert_equal(Image.maximum(:id),
                 ImageGapCheckpoint.last_verified_image_id)
  end

  def test_reset_to_sets_the_mark
    ImageGapCheckpoint.reset_to(12_345)
    assert_equal(12_345, ImageGapCheckpoint.last_verified_image_id)
  end

  def test_advance_to_only_moves_forward
    ImageGapCheckpoint.reset_to(100)

    ImageGapCheckpoint.advance_to(50)
    assert_equal(100, ImageGapCheckpoint.last_verified_image_id)

    ImageGapCheckpoint.advance_to(150)
    assert_equal(150, ImageGapCheckpoint.last_verified_image_id)
  end

  def test_is_a_singleton
    ImageGapCheckpoint.reset_to(1)
    ImageGapCheckpoint.reset_to(2)
    assert_equal(1, ImageGapCheckpoint.count)
  end
end
