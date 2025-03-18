# frozen_string_literal: true

require "test_helper"

class VisualGroupTest < ActiveSupport::TestCase
  def test_merge
    vg1 = visual_groups(:visual_group_one)
    vg2 = visual_groups(:visual_group_two)
    total = vg1.images.count + vg2.images.count
    assert_not_equal(vg1.images.count, total)
    vg1.merge(vg2)
    vg1.reload
    assert_equal(vg1.images.count, total)
  end

  def test_merge_self
    vg1 = visual_groups(:visual_group_one)
    total = vg1.images.count
    vg1.merge(vg1)
    vg1.reload
    assert_equal(vg1.images.count, total)
  end

  def test_merge_failed_save
    vg1 = visual_groups(:visual_group_one)
    total = vg1.images.count
    vg1.stub(:visual_group_images, [mock_vgi]) do
      vg1.merge(vg1)
    end
    vg1.reload
    assert_equal(vg1.images.count, total)
  end

  def mock_vgi
    vgi = Minitest::Mock.new
    vgi.expect(:image_in_group?, false) do |_id|
      true
    end
    vgi.expect(:save, false)
    vgi.expect(:visual_group=, true) do |_group|
      true
    end
    vgi
  end
end
