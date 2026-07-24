# frozen_string_literal: true

require("application_system_test_case")

# #4895: the in-page (overlay) vote interface is a lazy-loading Turbo
# Frame now, not rendered inline -- Matrix::Box's fragment cache has
# no user component in its key, so baking vote state directly into
# that cached HTML would show one viewer's votes to everyone else.
# Confirms the frame actually fetches and renders real vote content in
# a real browser, not just that the shell markup is correct (already
# covered by component/controller tests).
class LazyVoteInterfaceSystemTest < ApplicationSystemTestCase
  def test_overlay_vote_frame_loads_real_content
    rolf = users("rolf")
    login!(rolf)

    obs = observations(:detailed_unknown_obs)
    image = obs.thumb_image
    assert_not_nil(image, "fixture needs a thumb image")

    visit("/#{obs.id}")
    assert_selector("body.observations__show")

    # `.vote-section` is opacity-0 hover-revealed -- Capybara treats
    # that as invisible by default, even though it's laid out and
    # IntersectionObserver-based lazy loading fires regardless.
    within("turbo-frame#image_vote_#{image.id}", visible: :all) do
      assert_selector("button.image-vote-link", text: "Okay",
                                                visible: :all, wait: 5)
    end
  end
end
