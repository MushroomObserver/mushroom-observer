# frozen_string_literal: true

require("test_helper")

module Components::Image
  class BaseTest < ComponentTestCase
    def test_view_template_raises_not_implemented
      instance = Components::Image::Base.new(user: nil, image: nil)

      assert_raises(NotImplementedError) { instance.view_template }
    end

    def test_img_id_prop_coerces_integer_to_string
      instance = Components::Image::Base.new(
        user: nil, image: nil, img_id: 123
      )

      assert_equal("123", instance.instance_variable_get(:@img_id))
    end

    def test_img_id_prop_accepts_string
      instance = Components::Image::Base.new(
        user: nil, image: nil, img_id: "provisional-1"
      )

      assert_equal("provisional-1", instance.instance_variable_get(:@img_id))
    end
  end
end
