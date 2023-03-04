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

    # These try to test the results of ajax calls, but huh?
    def test_image_vote
      image = images(:in_situ_image)
      assert_nil(image.users_vote(dick))
      put(:update, params: { id: images(:in_situ_image).id, value: 3 })

      login("dick")
      assert_nil(image.users_vote(dick))
      put(:update, params: { id: images(:in_situ_image).id, value: 3 })
      assert_equal(3, image.reload.users_vote(dick))

      put(:update, params: { id: images(:in_situ_image).id, value: 0 })
      assert_nil(image.reload.users_vote(dick))

      put(:update, params: { id: images(:in_situ_image).id, value: 99 })
      assert_response(:error)
      put(:update, params: { id: 99, value: 0 })
      assert_response(:error)
    end

    def test_image_vote_renders_partial
      # Arrange
      login("dick")

      # Act
      put(:update, params: { id: images(:in_situ_image).id, value: 3 })

      # Assert
      assert_template(layout: nil)
      assert_template(layout: false)
      assert_template(partial: "shared/_image_vote_links")
    end

    # They're not links, they're forms. `button_to`
    def test_image_vote_renders_correct_links
      # Arrange
      login("dick")

      # Act
      put(:update, params: { id: images(:in_situ_image).id, value: 3 })
      assert_select(
        "form[action='/images/#{images(:in_situ_image).id}/vote?vote=0']"
      )
      assert_select(
        "form[action='/images/#{images(:in_situ_image).id}/vote?vote=1']"
      )
      assert_select(
        "form[action='/images/#{images(:in_situ_image).id}/vote?vote=2']"
      )
      assert_select(
        "form[action='/images/#{images(:in_situ_image).id}/vote?vote=4']"
      )
    end

    def test_image_vote_renders_correct_data_attributes
      # Arrange
      login("dick")

      # Act
      put(:update, params: { id: images(:in_situ_image).id, value: 3 })

      # should show four vote links as dick already voted
      assert_select("[data-role='image_vote']", 4)
      # should show four vote links as dick already voted
      assert_select("[data-value]", 4)
    end
  end
end
