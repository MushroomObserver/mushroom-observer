# frozen_string_literal: true

require("test_helper")

class ExternalSiteLinkTest < ComponentTestCase
  def test_inat_link_renders_inat_label_and_id_no_date
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    html = render(Components::ExternalSiteLink.new(link: link))

    # iNat URLs render as "iNat <id>" where <id> is the URL minus the
    # iNat base URL. No date suffix on iNat — they're already date-
    # stamped on the iNat side.
    assert_html(html, "a[href='#{link.url}']", text: "iNat 234723")
    assert_no_html(html, "small")
  end

  def test_other_site_renders_on_site_label_and_date
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    html = render(Components::ExternalSiteLink.new(link: link))

    # Non-iNat sites render with "On <site>" label + a small element
    # carrying the link's creation date.
    assert_html(html, "a[href='#{link.url}']",
                text: :on_site.t(site: link.external_site.name))
    assert_html(html, "small", text: link.created_at.web_date)
  end
end
