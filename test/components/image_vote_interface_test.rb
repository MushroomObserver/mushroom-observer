# frozen_string_literal: true

require "test_helper"

class ImageCaptionVoteInterfaceTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_vote_interface_with_votes_enabled
    html = render_component(votes: true)

    assert_includes(html, "image_vote_#{@image.id}")
    assert_includes(html, "vote-meter")
    assert_match(/image-vote/, html)
  end

  def test_renders_nothing_with_votes_disabled
    html = render_component(votes: false)

    assert_equal("", html)
  end

  private

  def render_component(votes:)
    render(Components::ImageVoteInterface.new(
             user: @user,
             image: @image,
             votes: votes
           ))
  end
end
