# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class ReviewStatusControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_set_review_status_reviewer
      desc = name_descriptions(:coprinus_comatus_desc)
      assert_equal("unreviewed", desc.review_status)
      assert(rolf.in_group?("reviewers"))
      params = {
        id: desc.id,
        value: "vetted"
      }
      post_requires_login(:set_review_status, params)
      assert_redirected_to(action: :show_name, id: desc.name_id)
      assert_equal("vetted", desc.reload.review_status)
    end

    def test_set_review_status_non_reviewer
      desc = name_descriptions(:coprinus_comatus_desc)
      assert_equal("unreviewed", desc.review_status)
      assert_not(mary.in_group?("reviewers"))
      params = {
        id: desc.id,
        value: "vetted"
      }
      post_requires_login(:set_review_status, params, "mary")
      assert_redirected_to(action: :show_name, id: desc.name_id)
      assert_equal("unreviewed", desc.reload.review_status)
    end
  end
end
