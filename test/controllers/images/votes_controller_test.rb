# frozen_string_literal: true

require("test_helper")

# tests of Transforms controller
module Images
  class VotesControllerTest < FunctionalTestCase
    def test_cast_vote
      user = users(:mary)
      image = images(:in_situ_image)
      value = Image.maximum_vote
      login(user.login)

      assert_difference("ImageVote.count", 1, "Failed to cast vote") do
        put(:update, params: { image_id: image.id, value: value })
      end
      assert_redirected_to(image_path(image.id))
      vote = ImageVote.last
      assert(vote.image == image && vote.user == user && vote.value == value,
             "Vote not cast correctly")
    end

    def test_cast_vote_next
      user = users(:mary)
      image = images(:in_situ_image)
      value = Image.maximum_vote
      login(user.login)

      assert_difference("ImageVote.count", 1, "Failed to cast vote") do
        put(:update, params: { image_id: image.id, value: value, next: true })
      end
      assert_redirected_to(
        image_path(id: image.id, q: QueryRecord.last.id.alphabetize)
      )
      vote = ImageVote.last
      assert(vote.image == image && vote.user == user && vote.value == value,
             "Vote not cast correctly")
    end

    def test_image_vote
      image = images(:in_situ_image)
      assert_nil(image.users_vote(dick))
      put(:update, params: { image_id: image.id, value: 3 })

      login("dick")
      assert_nil(image.users_vote(dick))
      put(:update, params: { image_id: image.id, value: 3 })
      assert_equal(3, image.reload.users_vote(dick))

      put(:update, params: { image_id: image.id, value: 0 })
      assert_nil(image.reload.users_vote(dick))

      assert_raises(RuntimeError) do
        put(:update, xhr: true, params: { image_id: image.id, value: 99 })
      end
    end

    # These try to test the results of ajax calls.
    # AJAX now renders image_vote_links helper inline to avoid nested partial
    # def test_image_vote_renders_partial
    #   # Arrange
    #   login("dick")
    #   img_id = images(:in_situ_image).id

    #   # Act
    #   put(:update, xhr: true, params: { image_id: img_id, value: 3 })

    #   # Assert
    #   assert_template(layout: nil)
    #   assert_template(layout: false)
    #   assert_template(partial: "shared/_image_vote_links")
    # end
  end
end
