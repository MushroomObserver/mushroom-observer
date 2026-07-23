# frozen_string_literal: true

require("test_helper")
require("csv")
require("tempfile")
require("zip")
require(Rails.root.join("script/backfill_mycoportal_export_links").to_s)

# Full-coverage tests for the #4819 MyCoPortal export-link backfill. Most
# assertions run the whole pipeline (`#run`) against temp CSVs + fixtures,
# with output suppressed.
class BackfillMycoportalExportLinksTest < UnitTestCase
  def setup
    @site = ExternalSite.mycoportal
  end

  def test_creates_export_link_for_known_image
    image = images(:in_situ_image)

    run_script([occurrence_row(1, "MUOB 1")],
               [multimedia_row(1, image_url(image.id))])

    assert(link_for(image), "Expected an export ExternalLink for the image")
  end

  def test_accepts_both_image_url_host_shapes
    image = images(:in_situ_image)
    old_shape = "https://images.mushroomobserver.org/1280/#{image.id}.jpg"

    run_script([occurrence_row(1, "MUOB 1")],
               [{ "coreid" => "1", "identifier" => old_shape }])

    assert(link_for(image), "Expected the older image URL host to parse")
  end

  def test_dry_run_creates_no_links
    image = images(:in_situ_image)

    subject = run_script([occurrence_row(1, "MUOB 1")],
                         [multimedia_row(1, image_url(image.id))],
                         apply: false)

    assert_nil(link_for(image))
    assert_equal(
      1, subject.instance_variable_get(:@stats)[:images][:created]
    )
  end

  def test_already_present_is_skipped
    image = images(:in_situ_image)
    make_link(image)

    subject = run_script([occurrence_row(1, "MUOB 1")],
                         [multimedia_row(1, image_url(image.id))])

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:images][:already_present]
    )
    assert_equal(
      1,
      ExternalLink.where(target: image, external_site: @site,
                         relationship: :export).count,
      "Re-running should not create a duplicate export link"
    )
  end

  def test_image_already_present_is_written_to_skipped_report
    image = images(:in_situ_image)
    link = make_link(image)

    run_script([occurrence_row(1, "MUOB 1")],
               [multimedia_row(1, image_url(image.id))])

    skipped = CSV.read(@skipped_out, headers: true)
    row = skipped.find { |r| r["entity_type"] == "Image" }
    assert_not_nil(row, "Expected a skipped-image row in the report")
    assert_equal("1", row["occid"])
    assert_equal(image.id.to_s, row["image_id"])
    assert_equal(link.id.to_s, row["external_link_id"])
  end

  def test_created_link_stores_metadata_date_as_external_created_on
    image = images(:in_situ_image)
    multimedia_csv = write_csv(
      %w[coreid identifier MetadataDate],
      [{ "coreid" => "1", "identifier" => image_url(image.id),
         "MetadataDate" => "2019-07-22 17:05:18" }]
    )
    occurrences_csv = write_csv(%w[id catalogNumber],
                                [occurrence_row(1, "MUOB 1")])
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: "d", occurrences: occurrences_csv, multimedia: multimedia_csv,
      apply: true, keep_csvs: false, missing_out: @missing_out,
      skipped_out: @skipped_out
    )

    capture_io { subject.run }

    link = link_for(image)
    assert_not_nil(link, "Expected an export ExternalLink for the image")
    assert_equal(Date.new(2019, 7, 22), link.external_created_on)
  end

  def test_created_link_leaves_url_nil
    image = images(:in_situ_image)

    run_script([occurrence_row(1, "MUOB 1")],
               [multimedia_row(1, image_url(image.id))])

    assert_nil(
      link_for(image).url,
      "Image export links have no reliable external URL to store " \
      "(see plan doc) -- url should stay nil"
    )
  end

  def test_created_link_sets_last_synced_at
    image = images(:in_situ_image)
    before = Time.current

    run_script([occurrence_row(1, "MUOB 1")],
               [multimedia_row(1, image_url(image.id))])

    link = link_for(image)
    assert_not_nil(link, "Expected an export ExternalLink for the image")
    assert(link.last_synced_at >= before,
           "last_synced_at should be set when the link is created")
  end

  def test_already_present_touches_last_synced_at_when_applying
    image = images(:in_situ_image)
    link = make_link(image)
    link.update_column(:last_synced_at, 1.year.ago)

    run_script([occurrence_row(1, "MUOB 1")],
               [multimedia_row(1, image_url(image.id))])

    assert(link.reload.last_synced_at > 1.day.ago,
           "Re-running with --apply should bump last_synced_at on an " \
           "already-linked image")
  end

  def test_already_present_not_touched_in_dry_run
    image = images(:in_situ_image)
    link = make_link(image)
    link.update_column(:last_synced_at, 1.year.ago)

    run_script([occurrence_row(1, "MUOB 1")],
               [multimedia_row(1, image_url(image.id))], apply: false)

    assert(link.reload.last_synced_at < 1.day.ago,
           "A dry run should not write last_synced_at")
  end

  def test_image_not_found_locally_is_reported
    bogus_id = Image.maximum(:id).to_i + 1000

    subject = run_script([occurrence_row(1, "MUOB 1")],
                         [multimedia_row(1, image_url(bogus_id))])

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:images][:mo_missing]
    )
    missing = CSV.read(@missing_out, headers: true)
    row = missing.find { |r| r["entity_type"] == "Image" }
    assert_not_nil(row, "Expected a missing-image row in the report")
    assert_equal("1", row["occid"])
    assert_equal("1", row["mo_obs_id"])
    assert_equal(bogus_id.to_s, row["image_id"])
  end

  def test_unparseable_identifier_is_reported
    subject = run_script(
      [occurrence_row(1, "MUOB 1")],
      [{ "coreid" => "1", "identifier" => "https://example.com/not-mo.jpg" }]
    )

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:images][:unparseable]
    )
  end

  def test_creates_export_link_for_known_observation
    obs = observations(:coprinus_comatus_obs)

    run_script([occurrence_row(500, "MUOB #{obs.id}")], [])

    link = ExternalLink.find_by(target: obs, external_site: @site,
                                relationship: :export)
    assert_not_nil(link, "Expected an export ExternalLink for the obs")
    assert_equal("500", link.external_id,
                 "Observation links should store the occid as external_id")
    assert_nil(link.url,
               "url should be derived from external_id, not stored directly")
  end

  def test_observation_link_stores_date_entered_as_external_created_on
    obs = observations(:coprinus_comatus_obs)
    occurrences_csv = write_csv(
      %w[id catalogNumber dateEntered],
      [{ "id" => "500", "catalogNumber" => "MUOB #{obs.id}",
         "dateEntered" => "2019-07-22 14:38:43" }]
    )
    multimedia_csv = write_csv(%w[coreid identifier], [])
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: "d", occurrences: occurrences_csv, multimedia: multimedia_csv,
      apply: true, keep_csvs: false, missing_out: @missing_out,
      skipped_out: @skipped_out
    )

    capture_io { subject.run }

    link = ExternalLink.find_by(target: obs, external_site: @site,
                                relationship: :export)
    assert_not_nil(link, "Expected an export ExternalLink for the obs")
    assert_equal(Date.new(2019, 7, 22), link.external_created_on)
  end

  def test_observation_already_present_is_skipped
    obs = observations(:coprinus_comatus_obs)
    ExternalLink.create!(user: User.admin, target: obs,
                         external_site: @site, relationship: :export,
                         external_id: "500")

    subject = run_script([occurrence_row(500, "MUOB #{obs.id}")], [])

    assert_equal(
      1,
      subject.instance_variable_get(:@stats)[:observations][:already_present]
    )
    assert_equal(
      1,
      ExternalLink.where(target: obs, external_site: @site,
                         relationship: :export).count,
      "Re-running should not create a duplicate export link"
    )
  end

  def test_observation_already_present_is_written_to_skipped_report
    obs = observations(:coprinus_comatus_obs)
    link = ExternalLink.create!(user: User.admin, target: obs,
                                external_site: @site, relationship: :export,
                                external_id: "500")

    run_script([occurrence_row(500, "MUOB #{obs.id}")], [])

    skipped = CSV.read(@skipped_out, headers: true)
    row = skipped.find { |r| r["entity_type"] == "Observation" }
    assert_not_nil(row, "Expected a skipped-observation row in the report")
    assert_equal("500", row["occid"])
    assert_equal(obs.id.to_s, row["mo_obs_id"])
    assert_equal(link.id.to_s, row["external_link_id"])
  end

  def test_observation_not_found_locally_is_reported
    bogus_id = Observation.maximum(:id).to_i + 1000

    subject = run_script([occurrence_row(500, "MUOB #{bogus_id}")], [])

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:observations][:mo_missing]
    )
    missing = CSV.read(@missing_out, headers: true)
    row = missing.find { |r| r["entity_type"] == "Observation" }
    assert_not_nil(row, "Expected a missing-observation row in the report")
    assert_equal("500", row["occid"])
    assert_equal(bogus_id.to_s, row["mo_obs_id"])
  end

  def test_observation_unparseable_catalog_number_is_reported
    subject = run_script(
      [{ "id" => "500", "catalogNumber" => "not-a-muob-number" }], []
    )

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:observations][:unparseable]
    )
  end

  def test_invalid_record_is_logged_and_skipped
    image = images(:in_situ_image)
    stubbed_error = lambda do |*|
      link = ExternalLink.new
      link.errors.add(:base, "stubbed failure")
      raise(ActiveRecord::RecordInvalid.new(link))
    end

    subject = nil
    ExternalLink.stub(:create!, stubbed_error) do
      subject = run_script([occurrence_row(1, "MUOB 1")],
                           [multimedia_row(1, image_url(image.id))])
    end

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:images][:invalid]
    )
    assert_nil(link_for(image))
  end

  def test_progress_logging_at_interval
    subject = build
    subject.instance_variable_set(:@images_seen,
                                  BackfillMycoportalExportLinks::
                                    PROGRESS_EVERY - 1)

    _out, err = capture_io do
      subject.send(:process_image_batch, [{ occid: "1", image_id: nil }])
    end

    assert_match(
      /#{BackfillMycoportalExportLinks::PROGRESS_EVERY} images processed/o,
      err
    )
  end

  def test_stopwatch_formats_elapsed_duration
    stopwatch = BackfillMycoportalExportLinks::Stopwatch.new

    assert_equal("5s", stopwatch.send(:format_duration, 5))
    assert_equal("2m 5s", stopwatch.send(:format_duration, 125))
    assert_equal("1h 1m 5s", stopwatch.send(:format_duration, 3665))
  end

  def test_run_prints_elapsed_time_in_summary
    occurrences_csv = write_csv(%w[id catalogNumber],
                                [occurrence_row(1, "MUOB 1")])
    multimedia_csv = write_csv(%w[coreid identifier], [])
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: "d", occurrences: occurrences_csv, multimedia: multimedia_csv,
      apply: false, keep_csvs: false, missing_out: @missing_out,
      skipped_out: @skipped_out
    )

    out, = capture_io { subject.run }

    assert_match(/elapsed: (\d+h )?(\d+m )?\d+s/, out)
  end

  def test_parse_options_defaults_and_overrides
    defaults = BackfillMycoportalExportLinks::Options.parse([])
    assert_nil(defaults[:occurrences], "Nil by default -- looks for a zip")
    assert_nil(defaults[:multimedia], "Nil by default -- looks for a zip")
    assert_equal(BackfillMycoportalExportLinks::Options::DEFAULT_DWCA_DIR,
                 defaults[:dwca_dir])
    assert_equal(false, defaults[:keep_csvs])
    assert_equal(
      File.join(BackfillMycoportalExportLinks::Options::DEFAULT_DWCA_DIR,
                "mycoportal_backfill_missing.csv"),
      defaults[:missing_out],
      "missing_out should default to a path inside dwca_dir, not the CWD"
    )
    assert_equal(
      File.join(BackfillMycoportalExportLinks::Options::DEFAULT_DWCA_DIR,
                "mycoportal_backfill_skipped.csv"),
      defaults[:skipped_out],
      "skipped_out should default to a path inside dwca_dir, not the CWD"
    )

    opts = BackfillMycoportalExportLinks::Options.parse(
      ["--dwca-dir", "/tmp/somewhere",
       "--occurrences", "o.csv", "--multimedia", "m.csv",
       "--keep-csvs", "--missing-out", "n.csv", "--skipped-out", "s.csv"]
    )
    assert_equal("/tmp/somewhere", opts[:dwca_dir])
    assert_equal("o.csv", opts[:occurrences])
    assert_equal("m.csv", opts[:multimedia])
    assert_equal(true, opts[:keep_csvs])
    assert_equal("n.csv", opts[:missing_out])
    assert_equal("s.csv", opts[:skipped_out])
  end

  def test_parse_options_reports_default_relative_to_custom_dwca_dir
    opts = BackfillMycoportalExportLinks::Options.parse(
      ["--dwca-dir", "/tmp/somewhere-else"]
    )

    assert_equal(
      File.join("/tmp/somewhere-else", "mycoportal_backfill_missing.csv"),
      opts[:missing_out],
      "missing_out should track a --dwca-dir override when not given " \
      "explicitly"
    )
    assert_equal(
      File.join("/tmp/somewhere-else", "mycoportal_backfill_skipped.csv"),
      opts[:skipped_out],
      "skipped_out should track a --dwca-dir override when not given " \
      "explicitly"
    )
  end

  def test_initialize_requires_both_occurrences_and_multimedia_or_neither
    assert_raises(RuntimeError) do
      BackfillMycoportalExportLinks.new(
        dwca_dir: "d", apply: false, keep_csvs: false,
        occurrences: "o.csv", multimedia: nil, missing_out: "n.csv"
      )
    end
  end

  def test_offline_mode_never_deletes_caller_provided_files
    image = images(:in_situ_image)
    occurrences_csv = write_csv(%w[id catalogNumber],
                                [occurrence_row(1, "MUOB 1")])
    multimedia_csv = write_csv(%w[coreid identifier],
                               [multimedia_row(1, image_url(image.id))])
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: "d", occurrences: occurrences_csv,
      multimedia: multimedia_csv, apply: true, keep_csvs: false,
      missing_out: @missing_out, skipped_out: @skipped_out
    )

    capture_io { subject.run }

    assert_path_exists(occurrences_csv,
                       "Caller-provided occurrences.csv must never be deleted")
    assert_path_exists(multimedia_csv,
                       "Caller-provided multimedia.csv must never be deleted")
  end

  def test_run_extracts_from_a_real_zip_and_cleans_up_the_csvs
    image = images(:in_situ_image)
    dwca_dir = Dir.mktmpdir("test_dwca")
    build_dwca_zip(dwca_dir, "MUOB_backup_2026-01-01_000000_DwC-A.zip",
                   [occurrence_row(1, "MUOB 1")],
                   [multimedia_row(1, image_url(image.id))])

    run_against_zip_dir(dwca_dir, keep_csvs: false)

    assert(link_for(image), "Expected an export ExternalLink for the image")
    assert_not(File.exist?(File.join(dwca_dir, "occurrences.csv")),
               "Extracted occurrences.csv should be cleaned up")
    assert_not(File.exist?(File.join(dwca_dir, "multimedia.csv")),
               "Extracted multimedia.csv should be cleaned up")
    assert_path_exists(
      File.join(dwca_dir, "MUOB_backup_2026-01-01_000000_DwC-A.zip"),
      "The zip itself should never be deleted"
    )
  ensure
    FileUtils.remove_entry(dwca_dir) if dwca_dir && Dir.exist?(dwca_dir)
  end

  def test_keep_csvs_option_retains_extracted_files
    image = images(:in_situ_image)
    dwca_dir = Dir.mktmpdir("test_dwca")
    build_dwca_zip(dwca_dir, "MUOB_backup_2026-01-01_000000_DwC-A.zip",
                   [occurrence_row(1, "MUOB 1")],
                   [multimedia_row(1, image_url(image.id))])

    run_against_zip_dir(dwca_dir, keep_csvs: true)

    assert_path_exists(File.join(dwca_dir, "occurrences.csv"),
                       "occurrences.csv should be kept when --keep-csvs " \
                       "is set")
    assert_path_exists(File.join(dwca_dir, "multimedia.csv"),
                       "multimedia.csv should be kept when --keep-csvs " \
                       "is set")
  ensure
    FileUtils.remove_entry(dwca_dir) if dwca_dir && Dir.exist?(dwca_dir)
  end

  def test_picks_the_newest_matching_zip
    image = images(:in_situ_image)
    dwca_dir = Dir.mktmpdir("test_dwca")
    older = build_dwca_zip(dwca_dir, "MUOB_backup_2020-01-01_000000_DwC-A.zip",
                           [occurrence_row(999, "MUOB 999")],
                           [multimedia_row(999, image_url(999_999_999))])
    # File.utime needs a plain Time, not an ActiveSupport::TimeWithZone --
    # #to_time converts without going through the flagged Time.now/Time.new.
    old_time = Time.current.to_time - 100
    File.utime(old_time, old_time, older)
    build_dwca_zip(dwca_dir, "MUOB_backup_2026-01-01_000000_DwC-A.zip",
                   [occurrence_row(1, "MUOB 1")],
                   [multimedia_row(1, image_url(image.id))])

    run_against_zip_dir(dwca_dir, keep_csvs: false)

    assert(link_for(image),
           "Should have processed the newer zip's image, not the older one's")
  ensure
    FileUtils.remove_entry(dwca_dir) if dwca_dir && Dir.exist?(dwca_dir)
  end

  def test_raises_when_no_matching_zip_is_found
    dwca_dir = Dir.mktmpdir("test_dwca_empty")
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: dwca_dir, occurrences: nil, multimedia: nil,
      apply: true, keep_csvs: false, missing_out: @missing_out,
      skipped_out: @skipped_out
    )

    error = assert_raises(RuntimeError) { capture_io { subject.run } }

    assert_match(/No .*DwC-A\.zip found/, error.message)
  ensure
    FileUtils.remove_entry(dwca_dir) if dwca_dir && Dir.exist?(dwca_dir)
  end

  def test_parse_options_apply_from_env
    ENV["APPLY"] = "1"
    assert(BackfillMycoportalExportLinks::Options.parse([])[:apply])
  ensure
    ENV.delete("APPLY")
  end

  private

  def build
    BackfillMycoportalExportLinks.new(
      dwca_dir: "d", occurrences: "o.csv",
      multimedia: "m.csv", apply: false, keep_csvs: false,
      missing_out: "n.csv", skipped_out: "s.csv"
    )
  end

  def occurrence_row(id, catalog_number)
    { "id" => id.to_s, "catalogNumber" => catalog_number }
  end

  def multimedia_row(coreid, identifier)
    { "coreid" => coreid.to_s, "identifier" => identifier }
  end

  def image_url(image_id)
    "https://mushroomobserver.org/images/1280/#{image_id}.jpg"
  end

  def make_link(image)
    ExternalLink.create!(user: User.admin, target: image,
                         external_site: @site, relationship: :export)
  end

  def link_for(image)
    ExternalLink.find_by(target: image, external_site: @site,
                         relationship: :export)
  end

  # Runs the backfill against temp CSVs (output suppressed) and returns the
  # instance so tests can inspect @stats. Report paths are @missing_out/
  # @skipped_out.
  def run_script(occurrence_rows, multimedia_rows, apply: true)
    occurrences_csv = write_csv(%w[id catalogNumber], occurrence_rows)
    multimedia_csv = write_csv(%w[coreid identifier], multimedia_rows)
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: "d", occurrences: occurrences_csv,
      multimedia: multimedia_csv, apply: apply, keep_csvs: false,
      missing_out: @missing_out, skipped_out: @skipped_out
    )
    capture_io { subject.run }
    subject
  end

  # Runs the backfill against a real dwca_dir (no --occurrences/
  # --multimedia given), so #run really globs for a zip and extracts it.
  def run_against_zip_dir(dwca_dir, keep_csvs:)
    @missing_out = temp_csv_path("missing")
    @skipped_out = temp_csv_path("skipped")
    subject = BackfillMycoportalExportLinks.new(
      dwca_dir: dwca_dir, occurrences: nil, multimedia: nil,
      apply: true, keep_csvs: keep_csvs, missing_out: @missing_out,
      skipped_out: @skipped_out
    )
    capture_io { subject.run }
    subject
  end

  # Builds a real zip (matching ZIP_NAME_GLOB) containing occurrences.csv/
  # multimedia.csv with the given rows. Returns the zip's path.
  def build_dwca_zip(dwca_dir, filename, occurrence_rows, multimedia_rows)
    zip_path = File.join(dwca_dir, filename)
    occurrences_content = csv_string(%w[id catalogNumber], occurrence_rows)
    multimedia_content = csv_string(%w[coreid identifier], multimedia_rows)
    Zip::File.open(zip_path, create: true) do |zip|
      zip.get_output_stream("occurrences.csv") do |f|
        f.write(occurrences_content)
      end
      zip.get_output_stream("multimedia.csv") do |f|
        f.write(multimedia_content)
      end
    end
    zip_path
  end

  def csv_string(headers, rows)
    CSV.generate do |csv|
      csv << headers
      rows.each { |row| csv << headers.map { |h| row[h] } }
    end
  end

  def write_csv(headers, rows)
    path = temp_csv_path("csv")
    write_csv_to(path, headers, rows)
    path
  end

  # Retains the Tempfile object (not just its path) for the rest of the
  # test -- otherwise Ruby's GC can finalize (unlink) it once nothing else
  # references it, even after the script has since written fresh content
  # to that same path, causing an intermittent ENOENT unrelated to
  # whatever the test is actually checking.
  def temp_csv_path(prefix)
    file = Tempfile.new([prefix, ".csv"])
    (@tempfiles ||= []) << file
    file.path
  end

  def write_csv_to(path, headers, rows)
    CSV.open(path, "w") do |csv|
      csv << headers
      rows.each { |row| csv << headers.map { |h| row[h] } }
    end
  end
end
