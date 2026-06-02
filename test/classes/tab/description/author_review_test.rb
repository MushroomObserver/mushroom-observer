# frozen_string_literal: true

require("test_helper")

module Tab::Description
  class AuthorReviewTest < UnitTestCase
    def setup
      @description = name_descriptions(:agaricus_campestras_desc)
    end

    def test_author_review
      tabs = Tab::Description::AuthorReview.new(object: @description).to_a

      assert_equal(
        [Tab::Object::ShowParent, Tab::Object::Show],
        tabs.map(&:class)
      )
    end
  end
end
