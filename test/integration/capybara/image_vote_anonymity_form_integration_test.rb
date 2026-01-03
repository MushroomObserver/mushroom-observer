# frozen_string_literal: true

require("test_helper")

# Simple smoke test for image vote anonymity form submission
class ImageVoteAnonymityFormIntegrationTest < CapybaraIntegrationTestCase
  def test_make_votes_public
    # Login as a user who has cast image votes
    user = users(:rolf)
    login(user)

    # Set all of rolf's votes to anonymous first so we can test making them
    # public
    ImageVote.where(user_id: user.id).update_all(anonymous: true)

    # Visit the vote anonymity edit page
    visit(images_edit_vote_anonymity_path)
    assert_selector("body.anonymity__edit")

    # Click the "Make all votes public" button
    click_button("Make all votes public")

    # Verify successful update (redirects to preferences)
    assert_selector("body.preferences__edit")

    # Verify all votes are now public
    assert_equal(0, ImageVote.where(user_id: user.id, anonymous: true).count)
  end
end
