# frozen_string_literal: true

require("test_helper")
require "prawn/measurement_extensions"

class ObservationLabelsTest < UnitTestCase
  def test_error_case
    new_root = Pathname.new("/tmp/fake_rails_root")
    Rails.stub(:root, new_root) do
      log_contents = with_captured_logger do
        obs = Observation.first
        doc = ObservationLabels.new(
          rolf,
          Query.lookup(:Observation, id_in_set: [obs.id])
        )
        doc.body
      end
      assert_match(/Helvetica/, log_contents)
    end
  end

  # qr_fields adds an iNat QR field for an imported obs, using the import
  # link's derived URL (link_url) and external_id.
  def test_qr_fields_inat_import_link
    obs = observations(:imported_inat_obs)
    link = obs.import_link
    fields = ObservationLabels::Fields.new(obs).qr_fields

    inat = fields.find { |f| f.label.start_with?("iNat:") }
    assert_not_nil(inat, "Imported obs should get an iNat QR field")
    assert_equal("iNat: #{link.external_id}", inat.label)
    assert_equal(link.link_url, inat.url)
  end

  # No iNat QR field when the import link has no external_id, nor for a
  # non-imported observation.
  def test_qr_fields_without_inat_external_id
    obs = observations(:imported_inat_obs)
    obs.import_link.update_columns(external_id: nil)
    obs.external_links.reload
    labels = ObservationLabels::Fields.new(obs).qr_fields.map(&:label)
    assert_empty(labels.grep(/\Ainat:/i), "Blank external_id => no iNat field")

    native = observations(:minimal_unknown_obs)
    native_labels = ObservationLabels::Fields.new(native).qr_fields.map(&:label)
    assert_empty(native_labels.grep(/\Ainat:/i),
                 "Non-imported obs should get no iNat field")
  end
end
