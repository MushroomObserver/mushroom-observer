# frozen_string_literal: true

require("test_helper")

class ImportedSourceBannerTest < ComponentTestCase
  def test_renders_for_imported_observation
    obs = observations(:imported_inat_obs)
    html = render(Components::ImportedSourceBanner.new(observation: obs))

    assert_html(html, "div.imported-source-banner")
    selector = "a[href*='inaturalist.org/observations/']" \
               "[target='_blank'][rel='noopener noreferrer']"
    assert_html(html, selector)
    # Link text includes the external (iNat) id so users can see / search
    # for the specific record on the source platform.
    assert_match(/Imported from iNaturalist #{obs.external_id}/, html)
    # (?) help link to article 39, on-site, NOT a new tab.
    assert_html(html, "a[href='/articles/39']")
    assert_html(html, "span.glyphicon.glyphicon-question-sign")
    assert_no_match(%r{href="/articles/39"[^>]*target=}, html,
                    "Help link should not open in a new tab")
  end

  def test_renders_plain_text_when_no_observation_url
    obs = observations(:imported_inat_obs)
    blank_source = Source.create!(name: "BlankSource")
    obs.update!(external_source: blank_source)

    html = render(Components::ImportedSourceBanner.new(observation: obs))

    assert_html(html, "div.imported-source-banner")
    assert_match(/Imported from BlankSource #{obs.external_id}/, html)
    assert_no_match(/<a[^>]*target="_blank"/, html,
                    "Should not render a target=_blank link without a URL")
    # Help link still appears.
    assert_html(html, "a[href='/articles/39']")
  end

  def test_renders_nothing_for_non_external_observation
    obs = observations(:detailed_unknown_obs) # source: mo_website
    assert_nil(obs.external_source)

    html = render(Components::ImportedSourceBanner.new(observation: obs))

    assert_equal("", html.to_s.strip,
                 "Banner should hide silently for non-imported obs")
  end
end
