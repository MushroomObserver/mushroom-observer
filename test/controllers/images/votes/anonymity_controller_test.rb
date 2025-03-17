# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Images::Votes
  class AnonymityControllerTest < FunctionalTestCase
    # Test setting anonymity of all image votes.
    def test_bulk_image_vote_anonymity_thingy
      img1 = images(:in_situ_image)
      img2 = images(:commercial_inquiry_image)
      img1.change_vote(mary, 1, anon: false)
      img2.change_vote(mary, 2, anon: true)
      img1.change_vote(rolf, 3, anon: true)
      img2.change_vote(rolf, 4, anon: false)

      assert_not(ImageVote.find_by(image_id: img1.id,
                                   user_id: mary.id).anonymous)
      assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
      assert(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
      assert_not(ImageVote.find_by(image_id: img2.id,
                                   user_id: rolf.id).anonymous)

      requires_login(:edit)
      assert_template("edit")

      login("mary")
      post(:update, params: { commit: :image_vote_anonymity_make_anonymous.l })
      assert_redirected_to(edit_account_preferences_path)
      assert(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
      assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
      assert(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
      assert_not(ImageVote.find_by(image_id: img2.id,
                                   user_id: rolf.id).anonymous)

      login("rolf")
      post(:update,
           params: { commit: :image_vote_anonymity_make_public.l })
      assert_redirected_to(edit_account_preferences_path)
      assert(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
      assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
      assert_not(ImageVote.find_by(image_id: img1.id,
                                   user_id: rolf.id).anonymous)
      assert_not(ImageVote.find_by(image_id: img2.id,
                                   user_id: rolf.id).anonymous)
    end

    def test_bulk_vote_anonymity_updater_bad_commit_param
      login("rolf")
      post(:update, params: { commit: "bad commit" })

      assert_flash_error
      assert_redirected_to(edit_account_preferences_path)
    end
  end
end
