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
      vote = ImageVote.find_by(image: image, user: user)
      assert_not_nil(vote, "Cannot find ImageVote")
      assert_equal(value, vote.value, "Vote not cast correctly")
    end

    def test_cast_vote_next
      user = users(:mary)
      image = images(:in_situ_image)
      value = Image.maximum_vote
      login(user.login)

      assert_difference("ImageVote.count", 1, "Failed to cast vote") do
        put(:update, params: { image_id: image.id, value: value, next: true })
      end
      # The original test reconstructed the expected URL from QueryRecord.last,
      # but that's the same record the controller used — a tautology. It also
      # races in parallel test runs. The meaningful assertion is just that
      # next: true produces a redirect with a q param (unlike test_cast_vote).
      assert_match(%r{/images/#{image.id}\?q}, response.location)
      vote = ImageVote.find_by(image: image, user: user)
      assert_not_nil(vote, "Cannot find ImageVote")
      assert_equal(value, vote.value, "Vote not cast correctly")
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

    # Two turbo-stream targets, not one: the in-page vote section
    # (:overlay context) and the lightbox caption's copy (:lightbox
    # context, a `lightbox_`-prefixed id) -- both can be live in the
    # DOM at once once the lightbox is open. See
    # Components::ImageFragment::VoteInterface#vote_html_id.
    def test_cast_vote_turbo_stream
      image = images(:in_situ_image)
      login(users(:mary).login)

      put(:update, params: { image_id: image.id, value: Image.maximum_vote },
                   format: :turbo_stream)

      assert_response(:success)
      assert_select("turbo-stream[action='replace']" \
                    "[target='image_vote_#{image.id}']")
      assert_select("turbo-stream[action='replace']" \
                    "[target='lightbox_image_vote_#{image.id}']")
    end

    # #4895: renders the vote interface fresh, uncached, for one
    # image -- the endpoint a lazy Turbo Frame fetches instead of
    # rendering vote state inline inside Matrix::Box's shared
    # fragment-cached HTML.
    def test_show_renders_vote_interface
      image = images(:in_situ_image)
      login(users(:mary).login)

      get(:show, params: { image_id: image.id })

      assert_response(:success)
      assert_select("turbo-frame#image_vote_#{image.id}")
      assert_select("turbo-frame .vote-section#image_vote_#{image.id}")
    end

    def test_show_lightbox_context
      image = images(:in_situ_image)
      login(users(:mary).login)

      get(:show, params: { image_id: image.id, context: "lightbox" })

      assert_response(:success)
      assert_select("turbo-frame#lightbox_image_vote_#{image.id}")
      assert_select("turbo-frame .vote-section-lightbox" \
                    "#lightbox_image_vote_#{image.id}")
    end

    # Anonymous viewers can load the frame too (`.require-user`
    # CSS-hides voting for them) -- `login_required` is skipped for
    # `show` specifically, unlike every other action on this
    # controller.
    def test_show_does_not_require_login
      image = images(:in_situ_image)

      get(:show, params: { image_id: image.id })

      assert_response(:success)
      assert_select("turbo-frame#image_vote_#{image.id}")
    end

    # A plain 404, not `find_or_goto_index`'s flash+redirect-to-index
    # -- this is a frame-only fetch, so a redirect would try to swap
    # a full index page into the tiny vote frame instead of just
    # leaving it empty.
    def test_show_with_missing_image_is_not_found
      get(:show, params: { image_id: -1 })

      assert_response(:not_found)
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
