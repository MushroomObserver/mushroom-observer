# frozen_string_literal: true

require("test_helper")

class Inat
  class ConfirmURLBuilderTest < ::UnitTestCase
    SITE_URL = "#{Inat::Constants::SITE}/observations".freeze

    def setup
      @username_model = FormObject::InatImportConfirm.new(
        inat_username: "testuser"
      )
    end

    def test_requested_obs_url_for_username_model
      builder = build(@username_model)

      assert_match(/user_id=testuser/, builder.requested_obs_url,
                   "requested_obs_url should include username")
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

    # MO asks the API for its two importable taxa by id; the UI says the
    # same thing with the iconic-taxa boxes, which a reader of the page
    # can see and change.
    def test_requested_obs_url_translates_the_importable_pair
      args = requested_link_args(
        "taxon_id=#{Inat::Constants::IMPORTABLE_TAXON_IDS_ARG}"
      )

      assert_equal(Inat::Constants::IMPORTABLE_ICONIC_TAXA_ARG,
                   args["iconic_taxa"],
                   "The importable pair reads as iconic taxa in the UI")
      assert_nil(args["taxon_id"], "The API spelling means one id there")
      assert_nil(args["taxon_ids"], "The pair needs no id list")
    end

    # A project searches for the taxa it tracks, which the UI reads from
    # plural taxon_ids. Dropping the list for iconic_taxa searched every
    # fungus in the project area and dates instead, so the links beside
    # the counts disagreed with the counts (#5729).
    def test_requested_obs_url_keeps_a_project_taxon_list
      args = requested_link_args("taxon_id=48701,54134,118000&place_id=14")

      assert_equal("48701,54134,118000", args["taxon_ids"],
                   "The UI reads a taxon list from plural taxon_ids")
      assert_nil(args["taxon_id"],
                 "The API spelling means one id to the UI")
      assert_nil(args["iconic_taxa"],
                 "A project tracking named taxa does not want every fungus")
    end

    def test_expected_obs_url_keeps_a_project_taxon_list
      args = expected_link_args("taxon_id=48701,54134,118000&place_id=14")

      assert_equal("48701,54134,118000", args["taxon_ids"],
                   "The expected-obs link keeps the project list too")
      assert_nil(args["iconic_taxa"],
                 "A taxon list is already a taxon filter")
    end

    # Regression (#4809): links on the confirm form must always point at
    # the iNat UI host, even when the user submitted an api.inaturalist.org
    # URL — api.inaturalist.org has no browsable UI for these paths.
    def test_requested_obs_url_uses_ui_host_for_api_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "https://api.inaturalist.org/v1/observations" \
                  "?project_id=fundis-rocky-mountain-rare-fungi-challenge"
      )
      builder = build(model)

      url = builder.requested_obs_url
      assert(url.start_with?("#{SITE_URL}?"),
             "Confirm-form links must use iNat UI host, never the API")
    end

    # Regression: a URL with leading/trailing whitespace must not be
    # re-encoded as a query param value (producing "?+++https%3A%2F%2F...").
    def test_requested_obs_url_strips_leading_whitespace_from_url
      model = FormObject::InatImportConfirm.new(
        original_inat_url: "   #{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      url = builder.requested_obs_url
      assert(url.start_with?("#{SITE_URL}?"),
             "Expected URL to start with #{SITE_URL}, got: #{url}")
      assert_match(/user_id=testuser/, url)
    end

    # A URL with no `id=` param is not stable — even a past date range can
    # gain new observations or reidentifications.
    def test_stable_result_set_returns_false_for_date_filtered_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?d1=2026-05-01&d2=2026-05-31"
      )
      builder = build(model)

      assert_not(builder.stable_result_set?,
                 "A URL with only date filters should not be considered stable")
    end

    def test_stable_result_set_returns_false_for_username_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      assert_not(builder.stable_result_set?,
                 "A URL with only a username should not be considered stable")
    end

    def test_stable_result_set_returns_true_for_id_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?id=123,456"
      )
      builder = build(model)

      assert(builder.stable_result_set?,
             "A URL with only id params (id=) should be considered stable")
    end

    def test_expected_obs_url_uses_license_codes_for_import_others
      args = expected_link_args("project_id=303327", import_others: "1")

      assert_equal(Inat::Constants::LICENSED_FILTER[:license],
                   args["license"],
                   "Expected link should use the import's license codes")
      assert_nil(args["licensed"],
                 "Expected link should not use iNat's licensed filter")
    end

    def test_expected_obs_url_keeps_url_license_for_import_others
      args = expected_link_args("project_id=303327&license=cc0",
                                import_others: "1")

      assert_equal("cc0", args["license"],
                   "Expected link should keep the license filter in the URL")
    end

    def test_expected_obs_url_has_no_license_filter_with_skeletons
      args = expected_link_args("project_id=303327",
                                import_others: "1", create_skeletons: "1")

      assert_nil(args["license"],
                 "With skeletons, unlicensed obss are imported too")
    end

    def test_expected_obs_url_leaves_out_opted_out_observers
      ExcludedInatUser.create!(inat_login: "excluded_on_inat")
      users(:mary).update!(inat_username: "mary_on_inat",
                           inat_import_opt_out: true)
      args = expected_link_args("project_id=303327", import_others: "1")

      assert_equal(%w[excluded_on_inat mary_on_inat],
                   args["not_user_id"].split(",").sort,
                   "Expected link should leave out opted-out observers")

      args = expected_link_args("project_id=303327",
                                import_others: "1", create_skeletons: "1")

      assert_nil(args["not_user_id"],
                 "With skeletons, opted-out observers are imported too")
    end

    # Regression (#4706): a user-supplied iconic_taxa superset must be
    # narrowed to the importable subset, not passed through unfiltered.
    def test_expected_obs_url_strips_unimportable_iconic_taxa
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&iconic_taxa=Plantae,Fungi"
      )
      builder = build(model)

      url = builder.expected_obs_url
      assert_not_nil(url)
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal("Fungi", args["iconic_taxa"],
                   "Expected link should drop non-importable iconic taxa")
    end

    # iNat's search UI excludes unverifiable observations (no photo/sound
    # or no date) by default, undercounting results. The confirm-page
    # links must opt in to verifiable=any unless the user's own URL
    # already specifies a verifiable param.
    def test_requested_obs_url_defaults_verifiable_to_any
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      url = builder.requested_obs_url
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal("any", args["verifiable"],
                   "Requested-obs link should default verifiable to any")
    end

    def test_requested_obs_url_preserves_user_supplied_verifiable
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&verifiable=true"
      )
      builder = build(model)

      url = builder.requested_obs_url
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal("true", args["verifiable"],
                   "User-supplied verifiable param must not be overridden")
    end

    def test_expected_obs_url_defaults_verifiable_to_any
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      url = builder.expected_obs_url
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal("any", args["verifiable"],
                   "Expected-obs link should default verifiable to any")
    end

    def test_expected_obs_url_preserves_user_supplied_verifiable
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&verifiable=false"
      )
      builder = build(model)

      url = builder.expected_obs_url
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal("false", args["verifiable"],
                   "User-supplied verifiable param must not be overridden")
    end

    # Regression: a space after the comma (e.g. from "Plantae, Fungi")
    # must not defeat the importable-taxon match.
    def test_expected_obs_url_strips_whitespace_in_iconic_taxa
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&iconic_taxa=Plantae,+Fungi"
      )
      builder = build(model)

      url = builder.expected_obs_url
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal("Fungi", args["iconic_taxa"],
                   "Expected link should match Fungi despite whitespace")
    end

    # No iconic_taxa supplied: falls back to the full importable default.
    def test_expected_obs_url_defaults_iconic_taxa_when_absent
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser"
      )
      builder = build(model)

      url = builder.expected_obs_url
      args = Rack::Utils.parse_query(url.split("?", 2).last)
      assert_equal(Inat::Constants::IMPORTABLE_ICONIC_TAXA_ARG,
                   args["iconic_taxa"],
                   "Expected link should default to the importable taxa")
    end

    # User's iconic_taxa has zero overlap with the importable set: no
    # link can lead anywhere useful, so a plain, unlinked count shows
    # instead (#4706).
    def test_expected_obs_url_returns_nil_when_no_importable_overlap
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?user_id=testuser&iconic_taxa=Plantae"
      )
      builder = build(model)

      assert_nil(builder.expected_obs_url,
                 "Expected no link when iconic_taxa excludes all " \
                 "importable taxa")
    end

    private

    def build(model)
      Inat::ConfirmURLBuilder.new(model)
    end

    # The query args of the "requested" link for a URL import.
    def requested_link_args(query, **)
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?#{query}", **
      )
      url = build(model).requested_obs_url
      assert_not_nil(url, "Requested link should be built")
      Rack::Utils.parse_query(url.split("?", 2).last)
    end

    # The query args of the "expected" link for a URL import.
    def expected_link_args(query, **)
      model = FormObject::InatImportConfirm.new(
        inat_url: "#{SITE_URL}?#{query}", **
      )
      url = build(model).expected_obs_url
      assert_not_nil(url, "Expected link should be built")
      Rack::Utils.parse_query(url.split("?", 2).last)
    end
  end
end
