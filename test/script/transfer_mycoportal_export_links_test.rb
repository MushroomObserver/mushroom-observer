# frozen_string_literal: true

require("test_helper")
require("csv")
require("tempfile")
require(Rails.root.join("script/transfer_mycoportal_export_links").to_s)

# Tests for the #4819 dev->production MyCoPortal export-link transfer
# (script/transfer_mycoportal_export_links.rb). Mirrors the export/apply
# split of transfer_image_dhashes.rb: --export dumps local links to CSV,
# --apply idempotently creates whatever's missing on the target DB.
class TransferMycoportalExportLinksTest < UnitTestCase
  def setup
    @site = ExternalSite.mycoportal
  end

  def test_export_writes_local_export_links
    image = images(:in_situ_image)
    link = make_link(target: image, external_id: "1")

    path = run_export

    rows = CSV.read(path, headers: true)
    row = rows.find { |r| r["target_type"] == "Image" }
    assert_not_nil(row, "Expected the local export link to be exported")
    assert_equal(image.id.to_s, row["target_id"])
    assert_equal(link.external_id, row["external_id"])
  end

  def test_export_excludes_non_export_relationship
    image = images(:in_situ_image)
    make_link(target: image, relationship: :manual)

    path = run_export

    rows = CSV.read(path, headers: true)
    assert_nil(rows.find { |r| r["target_type"] == "Image" },
               "A non-export-relationship link should not be exported")
  end

  def test_export_excludes_other_external_sites
    image = images(:in_situ_image)
    other_site = external_sites(:inaturalist)
    ExternalLink.create!(user: User.admin, target: image,
                         external_site: other_site, relationship: :export)

    path = run_export

    rows = CSV.read(path, headers: true)
    assert_nil(rows.find { |r| r["target_type"] == "Image" },
               "A link on a different external site should not be exported")
  end

  def test_apply_creates_missing_image_link
    image = images(:in_situ_image)

    subject = run_apply([export_row(target: image)])

    link = ExternalLink.find_by(target: image, external_site: @site,
                                relationship: :export)
    assert_not_nil(link, "Expected an export ExternalLink to be created")
    assert_equal(User.admin, link.user)
    assert_equal(1, subject.instance_variable_get(:@stats)[:created])
  end

  def test_apply_creates_missing_observation_link_with_metadata
    obs = observations(:coprinus_comatus_obs)

    run_apply([export_row(target: obs, external_id: "500",
                          external_created_on: "2019-07-22")])

    link = ExternalLink.find_by(target: obs, external_site: @site,
                                relationship: :export)
    assert_not_nil(link, "Expected an export ExternalLink to be created")
    assert_equal("500", link.external_id)
    assert_equal(Date.new(2019, 7, 22), link.external_created_on)
  end

  def test_apply_skips_already_present_link
    image = images(:in_situ_image)
    make_link(target: image)

    subject = run_apply([export_row(target: image)])

    assert_equal(
      1, subject.instance_variable_get(:@stats)[:already_present]
    )
    assert_equal(
      1,
      ExternalLink.where(target: image, external_site: @site,
                         relationship: :export).count,
      "Re-running should not create a duplicate export link"
    )
  end

  def test_apply_invalid_record_is_logged_and_skipped
    image = images(:in_situ_image)
    stubbed_error = lambda do |*|
      link = ExternalLink.new
      link.errors.add(:base, "stubbed failure")
      raise(ActiveRecord::RecordInvalid.new(link))
    end

    subject = nil
    ExternalLink.stub(:create!, stubbed_error) do
      subject = run_apply([export_row(target: image)])
    end

    assert_equal(1, subject.instance_variable_get(:@stats)[:invalid])
    assert_nil(ExternalLink.find_by(target: image, external_site: @site,
                                    relationship: :export))
  end

  def test_apply_processes_rows_across_multiple_target_types
    image = images(:in_situ_image)
    obs = observations(:coprinus_comatus_obs)

    with_batch_size(1) do
      run_apply([export_row(target: image), export_row(target: obs)])
    end

    assert(ExternalLink.exists?(target: image, external_site: @site,
                                relationship: :export),
           "Expected the first batch (flushed mid-loop) to be processed")
    assert(ExternalLink.exists?(target: obs, external_site: @site,
                                relationship: :export),
           "Expected the second, trailing batch to also be processed")
  end

  def test_parse_argv
    export_opts = TransferMycoportalExportLinks.parse_argv(
      ["--export", "out.csv"]
    )
    assert_equal("out.csv", export_opts[:export])
    assert_nil(export_opts[:apply])

    apply_opts = TransferMycoportalExportLinks.parse_argv(
      ["--apply", "in.csv"]
    )
    assert_equal("in.csv", apply_opts[:apply])
    assert_nil(apply_opts[:export])
  end

  def test_run_requires_exactly_one_of_export_or_apply
    assert_raises(SystemExit) { TransferMycoportalExportLinks.new({}).run }
    assert_raises(SystemExit) do
      TransferMycoportalExportLinks.new(export: "e.csv", apply: "a.csv").run
    end
  end

  def test_export_then_apply_round_trip
    image = images(:in_situ_image)
    make_link(target: image, external_id: "1",
              external_created_on: "2019-07-22")

    path = run_export
    ExternalLink.delete_all # simulate an empty target DB
    run_apply_from_file(path)

    link = ExternalLink.find_by(target: image, external_site: @site,
                                relationship: :export)
    assert_not_nil(link, "Expected the round-tripped link to be created")
    assert_equal("1", link.external_id)
    assert_equal(Date.new(2019, 7, 22), link.external_created_on)
  end

  private

  def make_link(target:, relationship: :export, external_id: nil,
                external_created_on: nil)
    ExternalLink.create!(user: User.admin, target: target,
                         external_site: @site, relationship: relationship,
                         external_id: external_id,
                         external_created_on: external_created_on)
  end

  def export_row(target:, external_id: nil, external_created_on: nil)
    { "target_type" => target.class.name, "target_id" => target.id.to_s,
      "external_id" => external_id, "external_created_on" =>
        external_created_on }
  end

  def run_export
    path = temp_csv_path("export")
    capture_io { TransferMycoportalExportLinks.new(export: path).run }
    path
  end

  def run_apply(rows)
    path = temp_csv_path("apply")
    write_csv(path, rows)
    run_apply_from_file(path)
  end

  def run_apply_from_file(path)
    subject = TransferMycoportalExportLinks.new(apply: path)
    capture_io { subject.run }
    subject
  end

  def write_csv(path, rows)
    headers = %w[target_type target_id external_id external_created_on]
    CSV.open(path, "w") do |csv|
      csv << headers
      rows.each { |row| csv << headers.map { |h| row[h] } }
    end
  end

  # Retains the Tempfile object so Ruby's GC doesn't unlink it mid-test.
  def temp_csv_path(prefix)
    file = Tempfile.new([prefix, ".csv"])
    (@tempfiles ||= []) << file
    file.path
  end

  def with_batch_size(size)
    original = TransferMycoportalExportLinks::BATCH
    TransferMycoportalExportLinks.send(:remove_const, :BATCH)
    TransferMycoportalExportLinks.const_set(:BATCH, size)
    yield
  ensure
    TransferMycoportalExportLinks.send(:remove_const, :BATCH)
    TransferMycoportalExportLinks.const_set(:BATCH, original)
  end
end
