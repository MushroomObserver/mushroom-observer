# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/materialize_external_links").to_s)

class MaterializeExternalLinksTest < UnitTestCase
  def setup
    @subject = MaterializeExternalLinks.new(
      csv: "unused", apply: false, multi_out: "unused", missing_out: "unused"
    )
    # An obs with plain notes: no "Mirrored on iNaturalist" stamp, no
    # inaturalist.org URL, so classification falls through to the copy rule.
    @obs = observations(:minimal_unknown_obs)
  end

  # At most one copy per MO obs: only the oldest (lowest-id) iNat obs can be a
  # copy; every other historic-era link is remote_manual.
  def test_only_oldest_inat_obs_can_be_copy
    @subject.instance_variable_set(:@oldest_inat_by_mo, { 5 => "100" })

    assert_equal(:copy,
                 classify(mo_id: 5, inat_id: "100", inat_created: "2016-01-01"))
    assert_equal(:remote_manual,
                 classify(mo_id: 5, inat_id: "200", inat_created: "2016-01-01"))
  end

  # If the oldest iNat obs postdates the copy-service cutoff, there is no copy.
  def test_oldest_after_cutoff_is_not_copy
    @subject.instance_variable_set(:@oldest_inat_by_mo, { 5 => "100" })

    assert_equal(:remote_manual,
                 classify(mo_id: 5, inat_id: "100", inat_created: "2023-01-01"))
  end

  private

  def classify(row)
    @subject.send(:classify, @obs, [], row)
  end
end
