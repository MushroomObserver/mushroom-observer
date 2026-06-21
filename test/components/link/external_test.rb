# frozen_string_literal: true

require("test_helper")

class Components::Link::ExternalTest < ComponentTestCase
  # ---- Generic (content, path) form ----

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

  # ---- ExternalLink AR record (link:) form ----

  def test_inat_link_renders_inat_label_and_id_no_date
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    html = render(Components::Link::External.new(link: link))

    assert_html(html, "a[href='#{link.url}']" \
                      "[target='_blank'][rel='noopener noreferrer']",
                text: "iNat 234723")
    assert_no_html(html, "small")
  end

  def test_other_site_renders_on_site_label_and_date
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    html = render(Components::Link::External.new(link: link))

    assert_html(html,
                "a[href='#{link.url}']" \
                "[target='_blank'][rel='noopener noreferrer']",
                text: :on_site.t(site: link.external_site.name))
    assert_html(html, "small", text: link.created_at.web_date)
  end
end
