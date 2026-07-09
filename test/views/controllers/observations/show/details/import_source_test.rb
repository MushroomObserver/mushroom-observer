# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Details::ImportSourceTest <
  ComponentTestCase
  def test_renders_for_imported_observation
    obs = observations(:imported_inat_obs)
    inat_id = obs.import_link.external_id
    html = render(
      Views::Controllers::Observations::Show::Details::ImportSource.new(
        obs: obs
      )
    )

    assert_html(html, "p.obs-import-source#observation_import_source")
    selector = "a[href*='inaturalist.org/observations/']" \
               "[target='_blank'][rel='noopener noreferrer']"
    assert_html(html, selector)
    # Link text includes the external (iNat) id so users can see / search
    # for the specific record on the source platform.
    assert_html(html, selector,
                text: "Imported from iNaturalist #{inat_id}")
    # (?) help link to article 39, on-site, NOT a new tab.
    assert_html(html, "a[href='/articles/39']")
    assert_html(html, "span.glyphicon.glyphicon-question-sign")
    assert_no_html(html, "a[href='/articles/39'][target]",
                   "Help link should not open in a new tab")
  end

  def test_renders_without_trailing_id_when_external_id_blank
    obs = observations(:imported_inat_obs)
    obs.import_link.update!(external_id: nil)
    obs.external_links.reload

    html = render(
      Views::Controllers::Observations::Show::Details::ImportSource.new(
        obs: obs
      )
    )

    # Covers credit_text's no-id branch: text falls back to link[:text]
    # alone (no trailing space + id).
    assert_html(
      html,
      "p.obs-import-source a[href*='inaturalist.org/observations/']",
      text: "Imported from iNaturalist"
    )
    link = Nokogiri::HTML.fragment(html).at_css(
      "p.obs-import-source a[href*='inaturalist.org/observations/']"
    )
    assert_equal("Imported from iNaturalist", link.text.strip,
                 "Link text should not include trailing id space")
  end

  def test_renders_nothing_for_non_external_observation
    obs = observations(:detailed_unknown_obs) # source: mo_website
    assert_nil(obs.import_link)

    html = render(
      Views::Controllers::Observations::Show::Details::ImportSource.new(
        obs: obs
      )
    )

    assert_equal("", html.to_s.strip,
                 "Notice should hide silently for non-imported obs")
  end
end
