# frozen_string_literal: true

require "test_helper"

class VisualGroupTest < ActiveSupport::TestCase
  def test_add_images
    vg = visual_groups(:visual_group_one)
    initial_count = vg.images.count
    images = [images(:in_situ_image), images(:turned_over_image)]
    vg.add_images(images)
    assert_equal(vg.images.count, initial_count + images.count)
  end
end
