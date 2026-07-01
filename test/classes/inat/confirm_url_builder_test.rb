# frozen_string_literal: true

require("test_helper")

class Inat
  class ConfirmURLBuilderTest < ::UnitTestCase
    SITE_URL = "https://www.inaturalist.org/observations"

    def setup
      @estimated_at = Time.zone.now
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

    # Covers the rescue ArgumentError branch in
    # date_filtered_before_estimated_at? (lines 83–84): an unparseable date
    # string returns false without raising.
    def test_stable_result_set_returns_false_for_invalid_date_in_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&d2=not-a-date"
      )
      builder = build(model)

      assert_not(builder.stable_result_set?)
    end

    private

    def build(model)
      Inat::ConfirmURLBuilder.new(model, estimated_at: @estimated_at)
    end
  end
end
