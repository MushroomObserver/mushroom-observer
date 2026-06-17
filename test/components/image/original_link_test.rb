# frozen_string_literal: true

require("test_helper")

class ImageOriginalLinkTest < ComponentTestCase
  def setup
    super
    @image = images(:in_situ_image)
  end

  def test_renders_link_to_original_with_image_instance
    html = render(Components::Image::OriginalLink.new(image: @image))

    assert_html(html, "a[href='/images/#{@image.id}/original']",
                text: :image_show_original.l)
    assert_html(html, "a[target='_blank'][rel='noopener']")
    assert_html(html,
                "a[data-controller='image-loader']" \
                "[data-action='click->image-loader#load']" \
                "[data-image-loader-target='link']")

    # Stimulus reads these via dataset for in-flight UI swaps.
    # Presence-only — the localized strings contain typographic
    # apostrophes that get smart-quote-substituted in HTML output,
    # so don't compare the full string in CSS attribute selectors.
    doc = Nokogiri::HTML(html)
    a = doc.at_css("a[data-controller='image-loader']")
    assert(a, "Expected image-loader anchor")
    %w[loading maxed-out error].each do |kind|
      assert(a["data-#{kind}-text"].to_s.present?,
             "Expected data-#{kind}-text attribute on link")
    end
  end

  def test_renders_link_with_image_id
    html = render(Components::Image::OriginalLink.new(image_id: @image.id))

    assert_html(html, "a[href='/images/#{@image.id}/original']")
  end

  def test_applies_custom_link_class
    html = render(Components::Image::OriginalLink.new(image: @image,
                                                      link_class: "my-custom"))

    assert_html(html, "a.my-custom")
  end
end
