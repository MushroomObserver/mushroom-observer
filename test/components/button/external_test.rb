# frozen_string_literal: true

require("test_helper")

class Components::Button::ExternalTest < ComponentTestCase
  def test_renders_btn_default_with_external_attrs
    html = render(Components::Button::External.new(
                    name: "BLAST it",
                    url: "https://blast.ncbi.nlm.nih.gov"
                  ))

    assert_html(html,
                "a[href='https://blast.ncbi.nlm.nih.gov']",
                text: "BLAST it")
    assert_html(html, "a[target='_blank'][rel='noopener noreferrer']")
  end

  def test_accepts_style_override
    html = render(Components::Button::External.new(
                    name: "Go",
                    url: "https://example.com",
                    variant: :link
                  ))

    assert_html(html, "a[target='_blank'][rel='noopener noreferrer']")
  end

  def test_accepts_size
    html = render(Components::Button::External.new(
                    name: "Go",
                    url: "https://example.com",
                    size: :sm
                  ))

    assert_html(html, "a[target='_blank']")
  end

  def test_href_matches_url_kwarg
    url = "https://hobix.com/textile"
    html = render(Components::Button::External.new(
                    name: "Textile Docs",
                    url: url
                  ))

    assert_html(html, "a[href='#{url}']")
  end
end
