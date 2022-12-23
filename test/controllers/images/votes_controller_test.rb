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
        put(:update, params: { id: image.id, value: value })
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
        put(:update, params: { id: image.id, value: value, next: true })
      end
      assert_redirected_to(
        image_path(id: image.id, q: QueryRecord.last.id.alphabetize)
      )
      vote = ImageVote.last
      assert(vote.image == image && vote.user == user && vote.value == value,
             "Vote not cast correctly")
    end
  end
end
