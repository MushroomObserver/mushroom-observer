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

    # The form has two submit buttons, click the enabled one by value
    click_button("Make all votes anonymous")

    # Verify successful update (redirects to preferences)
    assert_selector("body.preferences__edit")
  end
end
