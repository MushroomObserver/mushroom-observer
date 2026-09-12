# frozen_string_literal: true

require("test_helper")

# See test/components/matrix/table_test.rb for the render-site coverage
# (streams emitted after the boxes) and
# test/components/image_fragment/lazy_vote_interface_test.rb for the
# per-frame fallback these streams replace.
class VoteInterfaceStreamsTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:in_situ_image)
  end

  def test_renders_replace_streams_for_both_contexts
    html = render_streams(images: [@image])

    assert_html(
      html,
      "turbo-stream[action='replace'][target='image_vote_#{@image.id}']"
    )
    assert_html(
      html,
      "turbo-stream[action='replace']" \
      "[target='lightbox_image_vote_#{@image.id}']"
    )
    # The stream payload is the full VoteInterface, wrapped in the
    # <template> Turbo requires.
    assert_html(
      html,
      "turbo-stream template div#image_vote_#{@image.id}.vote-section"
    )
    assert_html(
      html,
      "turbo-stream template " \
      "div#lightbox_image_vote_#{@image.id}.vote-section-lightbox"
    )
  end

  def test_deduplicates_images
    html = render_streams(images: [@image, @image])

    doc = Nokogiri::HTML.fragment(html)
    assert_equal(
      1,
      doc.css("turbo-stream[target='image_vote_#{@image.id}']").size
    )
  end

  def test_renders_nothing_for_empty_images
    assert_equal("", render_streams(images: []))
  end

  def test_renders_for_anonymous_viewer
    html = render_streams(images: [@image], user: nil)

    assert_html(
      html,
      "turbo-stream[target='image_vote_#{@image.id}'] .require-user"
    )
  end

  private

  def render_streams(images:, user: @user)
    render(Components::ImageFragment.new(
             type: :vote_interface_streams, images: images, user: user
           ))
  end
end
