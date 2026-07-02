# frozen_string_literal: true

require("test_helper")

class Inat
  class ConfirmURLBuilderTest < ::UnitTestCase
    SITE_URL = "https://www.inaturalist.org/observations"

    def setup
      @username_model = FormObject::InatImportConfirm.new(
        inat_username: "testuser"
      )
    end

    def test_requested_obs_url_for_username_model
      builder = build(@username_model)

      assert_match(/user_id=testuser/, builder.requested_obs_url)
    end

    # Covers the normalize_inat_ui_url branch (line 14): when the query is
    # a full http URL, requested_obs_url normalizes it rather than building
    # from scratch.
    def test_requested_obs_url_for_http_url_model
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      url = builder.requested_obs_url
      assert_not_nil(url)
      assert_match(/inaturalist\.org/, url)
      assert_match(/user_id=testuser/, url)
    end

    # Covers the comma-taxon_id branch in translate_api_to_ui_params (line 71):
    # taxon_id with commas is replaced by iconic_taxa=Fungi,Protozoa.
    def test_requested_obs_url_translates_comma_taxon_id
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?taxon_id=47170,47686"
      )
      builder = build(model)

      url = builder.requested_obs_url
      assert_match(/iconic_taxa/, url)
      assert_no_match(/taxon_id=47170/, url)
    end

    # Regression: a URL with leading/trailing whitespace must not be
    # re-encoded as a query param value (producing "?+++https%3A%2F%2F...").
    def test_requested_obs_url_strips_leading_whitespace_from_url
      model = FormObject::InatImportConfirm.new(
        original_inat_url: "   #{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      url = builder.requested_obs_url
      assert_match(%r{\Ahttps://www\.inaturalist\.org/observations\?}, url)
      assert_match(/user_id=testuser/, url)
    end

    # A URL with no `id=` param is not stable — even a past date range can
    # gain new observations or reidentifications.
    def test_stable_result_set_returns_false_for_date_filtered_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&d1=2026-05-01&d2=2026-05-31"
      )
      builder = build(model)

      assert_not(builder.stable_result_set?)
    end

    def test_stable_result_set_returns_false_for_username_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      assert_not(builder.stable_result_set?)
    end

    def test_stable_result_set_returns_true_for_id_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?id=123,456"
      )
      builder = build(model)

      assert(builder.stable_result_set?)
    end

    private

    def build(model)
      Inat::ConfirmURLBuilder.new(model)
    end
  end
end
