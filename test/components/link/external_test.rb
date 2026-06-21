# frozen_string_literal: true

require("test_helper")

class ExternalLinkTest < ComponentTestCase
  def test_renders_link_with_target_blank_and_noopener
    html = render(Components::Link::External.new("GBIF", "https://gbif.org"))

    assert_html(html, "a[href='https://gbif.org']" \
                      "[target='_blank']" \
                      "[rel='noopener noreferrer']",
                text: "GBIF")
  end

  def test_passes_extra_opts_through
    html = render(
      Components::Link::External.new("GBIF", "https://gbif.org",
                                     id: "gbif_link")
    )

    assert_html(html, "a[id='gbif_link'][target='_blank']")
  end

  def test_does_not_override_caller_class
    html = render(
      Components::Link::External.new("EOL", "https://eol.org",
                                     class: "my-class")
    )

    assert_html(html, "a.my-class[target='_blank']")
  end
end
