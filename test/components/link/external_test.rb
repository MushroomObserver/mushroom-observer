# frozen_string_literal: true

require("test_helper")

class Components::Link::ExternalTest < ComponentTestCase
  FakeTab = Struct.new(:title, :path, :html_options) do
    def initialize
      super("External Resource", "https://example.com",
            { class: "tab-class" })
    end
  end
  # ---- Generic (content, path) form ----

  def test_renders_link_with_target_blank_and_noopener
    html = render(Components::Link::External.new(
                    content: "GBIF", path: "https://gbif.org"
                  ))

    assert_html(html, "a[href='https://gbif.org']" \
                      "[target='_blank']" \
                      "[rel='noopener noreferrer']",
                text: "GBIF")
  end

  def test_passes_extra_opts_through
    html = render(
      Components::Link::External.new(
        content: "GBIF", path: "https://gbif.org", id: "gbif_link"
      )
    )

    assert_html(html, "a[id='gbif_link'][target='_blank']")
  end

  def test_does_not_override_caller_class
    html = render(
      Components::Link::External.new(
        content: "EOL", path: "https://eol.org", class: "my-class"
      )
    )

    assert_html(html, "a.my-class[target='_blank']")
  end

  # ---- Tab PORO form ----

  def test_tab_form_uses_tab_title_path_and_html_options
    tab = FakeTab.new
    html = render(Components::Link::External.new(tab: tab))

    assert_html(html, "a[href='https://example.com']" \
                      "[target='_blank'][rel='noopener noreferrer']",
                text: "External Resource")
    assert_html(html, "a.tab-class")
  end

  # ---- ExternalLink AR record (link:) form ----

  def test_inat_link_renders_relationship_id_and_date
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    html = render(Components::Link::External.new(link: link))

    assert_html(html, "a[href='#{link.url}']" \
                      "[target='_blank'][rel='noopener noreferrer']",
                text: "Manual link to iNaturalist (234723)")
    assert_includes(html, "#{link.relationship_date.web_date}: ")
    assert_no_html(html, "small")
  end

  # Regression: import links store external_id with a nil url (url is derived).
  # The component used to call link.url.sub(...) -> NoMethodError on nil.
  def test_inat_import_link_with_nil_url_renders_derived_id
    site = external_sites(:inaturalist)
    link = ExternalLink.new(external_site: site, relationship: :import,
                            external_id: "372490529")
    assert_nil(link.url, "Import links store external_id, not url")

    html = render(Components::Link::External.new(link: link))

    assert_html(html, "a[href='#{site.observation_url("372490529")}']" \
                      "[target='_blank'][rel='noopener noreferrer']",
                text: "Imported from iNaturalist (372490529)")
  end

  def test_other_site_renders_relationship_label_and_date
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    html = render(Components::Link::External.new(link: link))

    assert_html(html,
                "a[href='#{link.url}']" \
                "[target='_blank'][rel='noopener noreferrer']",
                text: "Manual link to MycoPortal")
    assert_includes(html, "#{link.relationship_date.web_date}: ")
    assert_no_html(html, "small")
  end
end
