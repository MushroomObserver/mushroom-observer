# frozen_string_literal: true

require("test_helper")

# Inat::Taxon must tolerate an observation with no taxon -- an iNat
# "Unknown", e.g. an identification withdrawn after import, which a
# resync can turn an existing reflection into. A batch resync over real
# data crashed here before the guards were added.
class Inat::TaxonTest < UnitTestCase
  def test_a_nil_taxon_is_handled_without_raising
    taxon = Inat::Taxon.new(nil)

    assert_nil(taxon[:name], "hash access on a nil taxon returns nil")
    assert_nil(taxon.name, "no MO Name matches a nil taxon")
    assert_nil(taxon.full_name_string)
    assert_not(taxon.importable?, "a nil taxon is not importable")
  end
end
