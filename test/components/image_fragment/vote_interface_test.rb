# frozen_string_literal: true

require "test_helper"

class ImageFragmentVoteInterfaceTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_vote_interface_with_votes_enabled
    html = render_component(votes: true)

    assert_includes(html, "image_vote_#{@image.id}")
    assert_includes(html, "vote-meter")
    assert_includes(html, "image-vote")
  end

  def test_renders_nothing_with_votes_disabled
    html = render_component(votes: false)

    assert_equal("", html)
  end

  # :overlay (default) -- the absolutely-positioned, hover-revealed
  # thumbnail treatment, plain (unprefixed) element ids.
  def test_overlay_context_is_the_default
    html = render_component

    assert_html(html, ".vote-section#image_vote_#{@image.id}")
    assert_no_html(html, ".vote-section-inline")
    assert_html(html, "#vote_meter_bar_#{@image.id}")
    assert_html(html, "#image_vote_links_#{@image.id}")
  end

  # :lightbox -- plain always-visible styling, and every id prefixed
  # so a live in-page :overlay copy and this :lightbox copy of the
  # same image's vote UI can coexist in the DOM without colliding.
  def test_lightbox_context_uses_inline_styling_and_prefixed_ids
    html = render_component(context: :lightbox)

    assert_html(html, ".vote-section-inline#lightbox_image_vote_#{@image.id}")
    assert_no_html(html, ".vote-section")
    assert_html(html, "#lightbox_vote_meter_bar_#{@image.id}")
    assert_html(html, "#lightbox_image_vote_links_#{@image.id}")
  end

  private

  def render_component(votes: true, context: :overlay)
    render(Components::ImageFragment::VoteInterface.new(
             user: @user,
             image: @image,
             votes: votes,
             context: context
           ))
  end
end
