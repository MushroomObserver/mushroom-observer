# frozen_string_literal: true

require("test_helper")

module Names::EolData
  class ExpandedReviewControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_eol_expanded_review
      requires_login(:show)
    end
  end
end
