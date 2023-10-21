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
      put_requires_login(:update, params)
      assert_redirected_to(name_path(desc.name_id))
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
      put_requires_login(:update, params, "mary")
      assert_redirected_to(name_path(desc.name_id))
      assert_equal("unreviewed", desc.reload.review_status)
    end
  end
end
