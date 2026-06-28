# frozen_string_literal: true

require("test_helper")
require("csv")
require("tempfile")
require(Rails.root.join("script/materialize_external_links").to_s)

# Full-coverage tests for the #4565 materializer. Most assertions run the whole
# pipeline (`#run`) against a temp CSV + fixtures, with output suppressed.
class MaterializeExternalLinksTest < UnitTestCase
  INAT = "https://www.inaturalist.org/observations/"

  def setup
    @site = ExternalSite.inaturalist
  end

  # ---------- end-to-end classification ----------

  def test_run_classifies_each_relationship
    copy   = obs_without_links(:minimal_unknown_obs)
    mirror = with_notes(:detailed_unknown_obs, "Mirrored on iNaturalist as x")
    manual = with_notes(:agaricus_campestris_obs, "see #{INAT}55")
    recent = obs_without_links(:agaricus_campestrus_obs)

    run_script([[10, "2016-01-02", mo_url(copy)],
                [20, "2016-03-04", mo_url(mirror)],
                [30, "2016-05-06", mo_url(manual)],
                [40, "2023-01-01", mo_url(recent)]])

    assert_equal("copy", link_for(copy, "10").relationship)
    assert_equal(Date.new(2016, 1, 2), link_for(copy, "10").external_created_on)
    assert_equal("mirror", link_for(mirror, "20").relationship)
    assert_equal("manual", link_for(manual, "30").relationship)
    assert_equal("remote_manual", link_for(recent, "40").relationship)
  end

  def test_dry_run_creates_no_links
    copy = obs_without_links(:minimal_unknown_obs)
    subject = run_script([[10, "2016-01-02", mo_url(copy)]], apply: false)

    assert_nil(link_for(copy, "10"))
    assert_equal(1, subject.instance_variable_get(:@stats)[:copy])
  end

  def test_import_link_makes_extra_ref_remote_manual
    obs = observations(:imported_inat_obs) # fixture has an import link
    assert(obs.external_links.any?(&:import?), "fixture needs an import link")

    run_script([[888, "2016-01-02", mo_url(obs)]])

    assert_equal("remote_manual", link_for(obs, "888").relationship)
  end

  # ---------- idempotency: skip + backfill + demote ----------

  def test_already_present_skips_and_backfills_date
    obs = obs_without_links(:minimal_unknown_obs)
    link = make_link(obs, external_id: "777", relationship: :copy)
    assert_nil(link.external_created_on)

    run_script([[777, "2016-07-08", mo_url(obs)]])

    assert_equal(Date.new(2016, 7, 8), link.reload.external_created_on)
    assert_equal(1, obs.external_links.where(external_site: @site).count)
  end

  def test_backfill_skipped_when_report_date_blank
    obs = obs_without_links(:minimal_unknown_obs)
    link = make_link(obs, external_id: "777", relationship: :copy)

    run_script([[777, "", mo_url(obs)]])

    assert_nil(link.reload.external_created_on)
  end

  def test_demotes_extra_copy_keeping_oldest
    obs = obs_without_links(:minimal_unknown_obs)
    older = make_link(obs, external_id: "100", relationship: :copy)
    newer = make_link(obs, external_id: "200", relationship: :copy)

    run_script([[100, "2016-01-01", mo_url(obs)],
                [200, "2016-02-02", mo_url(obs)]])

    assert_equal("copy", older.reload.relationship)
    assert_equal("remote_manual", newer.reload.relationship)
  end

  def test_non_copy_existing_link_is_not_demoted
    obs = obs_without_links(:minimal_unknown_obs)
    make_link(obs, external_id: "100", relationship: :copy)
    other = make_link(obs, external_id: "200", relationship: :manual)

    run_script([[100, "2016-01-01", mo_url(obs)],
                [200, "2016-02-02", mo_url(obs)]])

    assert_equal("manual", other.reload.relationship)
  end

  # legacy url-only link (no external_id): dedup matches via the parsed url
  def test_legacy_url_only_link_dedup
    obs = obs_without_links(:minimal_unknown_obs)
    link = make_link(obs, url: "#{INAT}654", relationship: :manual)
    assert_nil(link.external_id)

    run_script([[654, "2016-01-01", mo_url(obs)]])

    assert_equal(1, obs.external_links.where(external_site: @site).count)
  end

  # ---------- reports: missing, unparseable, multi-link ----------

  def test_mo_missing_and_unparseable
    subject = run_script(
      [[50, "2016-01-01", "https://mushroomobserver.org/observations/99999999"],
       [60, "2016-01-01", "https://example.com/not-mo"]]
    )
    stats = subject.instance_variable_get(:@stats)

    assert_equal(1, stats[:mo_missing])
    assert_equal(1, stats[:unparseable])
    missing = CSV.read(@missing_out, headers: true)
    assert_equal("99999999", missing.first["mo_obs_id"])
  end

  def test_multilink_report
    obs = obs_without_links(:minimal_unknown_obs)

    run_script([[100, "2016-01-01", mo_url(obs)],
                [200, "2016-02-02", mo_url(obs)]])

    row = CSV.read(@multi_out, headers: true).
          find { |r| r["mo_obs_id"].to_i == obs.id }
    assert_equal("2", row["inat_link_count"])
    assert_equal("100 200", row["inat_ids"])
  end

  # ---------- unit edges ----------

  def test_notes_blob_handles_non_hash_notes
    obs = observations(:minimal_unknown_obs)
    obs.stub(:notes, "Mirrored on iNaturalist") do
      assert_equal("Mirrored on iNaturalist", build.send(:notes_blob, obs))
    end
  end

  def test_progress_logging_at_interval
    subject = build
    subject.instance_variable_set(:@total, 20_000)
    subject.instance_variable_set(:@seen, 19_999)

    _out, err = capture_io do
      subject.send(:process_batch,
                   [{ mo_id: nil, inat_id: "1", url: "x", inat_created: "" }])
    end

    assert_match(%r{20000/20000 processed}, err)
  end

  def test_only_oldest_inat_obs_can_be_copy
    subject = build
    subject.instance_variable_set(:@oldest_inat_by_mo, { 5 => "100" })

    assert_equal(:copy, classify(subject, mo_id: 5, inat_id: "100",
                                          inat_created: "2016-01-01"))
    assert_equal(:remote_manual, classify(subject, mo_id: 5, inat_id: "200",
                                                   inat_created: "2016-01-01"))
  end

  def test_oldest_after_cutoff_is_not_copy
    subject = build
    subject.instance_variable_set(:@oldest_inat_by_mo, { 5 => "100" })

    assert_equal(:remote_manual, classify(subject, mo_id: 5, inat_id: "100",
                                                   inat_created: "2023-01-01"))
  end

  def test_parse_options_defaults_and_overrides
    assert_equal("inat-obs-report.csv", parse_options([])[:csv])

    opts = parse_options(["--csv", "a.csv",
                          "--multi-out", "m.csv", "--missing-out", "n.csv"])
    assert_equal("a.csv", opts[:csv])
    assert_equal("m.csv", opts[:multi_out])
    assert_equal("n.csv", opts[:missing_out])
  end

  def test_parse_options_apply_from_env
    ENV["APPLY"] = "1"
    assert(parse_options([])[:apply])
  ensure
    ENV.delete("APPLY")
  end

  private

  def build
    MaterializeExternalLinks.new(csv: "x", apply: false,
                                 multi_out: "m", missing_out: "n")
  end

  def classify(subject, row)
    subject.send(:classify, observations(:minimal_unknown_obs), [], row)
  end

  def mo_url(obs)
    "https://mushroomobserver.org/observations/#{obs.id}"
  end

  def obs_without_links(name)
    obs = observations(name)
    obs.external_links.destroy_all
    obs
  end

  def with_notes(name, text)
    obs = obs_without_links(name)
    obs.update!(notes: { Other: text })
    obs
  end

  def make_link(obs, **attrs)
    ExternalLink.create!(user: User.admin, target: obs,
                         external_site: @site, **attrs)
  end

  def link_for(obs, inat_id)
    ExternalLink.find_by(target: obs, external_site: @site,
                         external_id: inat_id)
  end

  # Runs the materializer against a temp CSV (output suppressed) and returns the
  # instance so tests can inspect @stats. Output report paths are @multi_out /
  # @missing_out.
  def run_script(rows, apply: true)
    csv = Tempfile.new(["report", ".csv"])
    CSV.open(csv.path, "w") do |c|
      c << ["id", "created_at", "field:mushroom observer url"]
      rows.each { |r| c << r }
    end
    @multi_out = Tempfile.new(["multi", ".csv"]).path
    @missing_out = Tempfile.new(["missing", ".csv"]).path
    subject = MaterializeExternalLinks.new(
      csv: csv.path, apply: apply,
      multi_out: @multi_out, missing_out: @missing_out
    )
    capture_io { subject.run }
    subject
  end
end
