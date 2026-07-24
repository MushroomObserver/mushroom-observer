# frozen_string_literal: true

require("application_system_test_case")

# Regression test for the lightbox's own copy of the vote interface
# (`context: :lightbox`, see Components::ImageFragment::VoteInterface)
# not updating live while the lightbox stays open on the same slide.
#
# lightGallery copies `.lightbox-caption`'s innerHTML into
# `.lg-sub-html` -- a separate DOM subtree, not a live reference --
# only on slide open/transition, never via a DOM mutation observer.
# A Turbo Stream vote update targets the id on the ORIGINAL hidden
# caption element; without something explicitly re-triggering the
# copy, the change lands there and never becomes visible in the open
# `.lg-sub-html` clone. See lightgallery_controller.js#refreshCaption
# (calls lightGallery's own `addHtml(index)` -- the method that
# actually does the copy; `gallery.refresh()` does not).
class LightboxVoteLiveUpdateSystemTest < ApplicationSystemTestCase
  def test_voting_in_open_lightbox_updates_live
    rolf = users("rolf")
    login!(rolf)

    obs = observations(:detailed_unknown_obs)
    image = obs.thumb_image
    assert_not_nil(image, "fixture needs a thumb image")
    assert_nil(image.users_vote(rolf), "fixture image should start unvoted")

    visit("/#{obs.id}")
    assert_selector("body.observations__show")

    first(".theater-btn", visible: :all).trigger("click")
    assert_selector(".lg-sub-html")

    within(".lg-sub-html") do
      assert_selector("button.image-vote-link", text: "Okay")
      click_button("Okay")
    end

    within(".lg-sub-html") do
      # A cast vote renders as a plain `<span class="image-vote">`,
      # not a clickable button (see VoteInterface#render_current_vote).
      # Seeing that -- without navigating away and back -- proves the
      # live update actually reached the visible `.lg-sub-html` copy,
      # not just the hidden original caption element.
      assert_selector("span.image-vote", text: "Okay", wait: 5)
      assert_no_selector("button.image-vote-link", text: "Okay")

      # `turbo_stream.replace`, not `update` -- VoteInterface's own
      # render output is the full `#lightbox_image_vote_<id>` wrapper,
      # so `update` would nest a duplicate-id div inside the original.
      assert_selector("#lightbox_image_vote_#{image.id}", count: 1)
    end
  end
end
