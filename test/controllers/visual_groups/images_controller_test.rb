# frozen_string_literal: true

require("test_helper")

module VisualGroups
  class ImagesControllerTest < FunctionalTestCase
    def test_visual_group_flip_status
      login
      visual_group = visual_groups(:visual_group_one)
      image = images(:agaricus_campestris_image)
      vgi = visual_group.visual_group_images.find_by(image_id: image.id)
      new_status = !vgi.included
      patch(:update,
            params: { visual_group_id: visual_group.id, id: image.id,
                      status: new_status })
      vgi.reload
      assert_equal(new_status, vgi.included)
    end

    def test_visual_group_delete_relationship
      login
      visual_group = visual_groups(:visual_group_one)
      image = images(:agaricus_campestris_image)
      count = VisualGroupImage.count
      patch(:update,
            params: { visual_group_id: visual_group.id, id: image.id,
                      status: "" })
      assert_equal(count - 1, VisualGroupImage.count)
    end

    def test_visual_group_add_relationship
      login
      visual_group = visual_groups(:visual_group_one)
      image = images(:peltigera_image)
      count = VisualGroupImage.count
      patch(:update,
            params: { visual_group_id: visual_group.id, id: image.id,
                      status: "true" })
      assert_equal(count + 1, VisualGroupImage.count)
    end
  end
end
