# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations
  class ImportedSourceBannerTest < ComponentTestCase
    def test_renders_for_imported_observation
      obs = observations(:imported_inat_obs)
      html = render(ImportedSourceBanner.new(observation: obs))

      assert_html(html, "div.imported-source-banner")
      selector = "a[href*='inaturalist.org/observations/']" \
                 "[target='_blank'][rel='noopener noreferrer']"
      assert_html(html, selector)
      # Link text includes the external (iNat) id so users can see / search
      # for the specific record on the source platform.
      assert_html(html, selector,
                  text: "Imported from iNaturalist #{obs.external_id}")
      # (?) help link to article 39, on-site, NOT a new tab.
      assert_html(html, "a[href='/articles/39']")
      assert_html(html, "span.glyphicon.glyphicon-question-sign")
      assert_no_html(html, "a[href='/articles/39'][target]",
                     "Help link should not open in a new tab")
    end

    def test_renders_plain_text_when_no_observation_url
      obs = observations(:imported_inat_obs)
      blank_source = Source.create!(name: "BlankSource")
      obs.update!(external_source: blank_source)

      html = render(ImportedSourceBanner.new(observation: obs))

      assert_html(html, "div.imported-source-banner",
                  text: "Imported from BlankSource #{obs.external_id}")
      assert_no_html(html, "a[target='_blank']",
                     "Should not render a target=_blank link without a URL")
      # Help link still appears.
      assert_html(html, "a[href='/articles/39']")
    end

    def test_renders_without_trailing_id_when_external_id_blank
      obs = observations(:imported_inat_obs)
      obs.update!(external_id: nil)

      html = render(ImportedSourceBanner.new(observation: obs))

      # Covers credit_text's no-id branch: text falls back to link[:text]
      # alone (no trailing space + id).
      assert_html(
        html,
        "div.imported-source-banner a[href*='inaturalist.org/observations/']",
        text: "Imported from iNaturalist"
      )
      link = Nokogiri::HTML(html).at_css(
        "div.imported-source-banner a[href*='inaturalist.org/observations/']"
      )
      assert_equal("Imported from iNaturalist", link.text.strip,
                   "Link text should not include trailing id space")
    end

    def test_renders_nothing_for_non_external_observation
      obs = observations(:detailed_unknown_obs) # source: mo_website
      assert_nil(obs.external_source)

      html = render(ImportedSourceBanner.new(observation: obs))

      assert_equal("", html.to_s.strip,
                   "Banner should hide silently for non-imported obs")
    end
  end
end
