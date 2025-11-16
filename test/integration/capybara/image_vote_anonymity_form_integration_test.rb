# frozen_string_literal: true

require("test_helper")

# Simple smoke test for image vote anonymity form submission
class ImageVoteAnonymityFormIntegrationTest < CapybaraIntegrationTestCase
  def test_change_vote_anonymity
    # Login as a user who has cast image votes
    user = users(:rolf)
    login(user)

    # Visit the vote anonymity edit page
    visit(images_edit_vote_anonymity_path)
    assert_selector("body.anonymity__edit")

    # The form has no input fields, just submit buttons
    # Click one of the submit buttons to test form submission
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    assert_selector("body")
  end
end
