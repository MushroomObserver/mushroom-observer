# frozen_string_literal: true

require("test_helper")

class NameObservationTest < UnitTestCase
  def test_where_proposed
    name = names(:lactarius_alpigenes)
    assert(name.deprecated?, "Test needs deprecated Name")
    assert_blank(Naming.where(name: name),
                 "Test needs name without Namings")
    assert_blank(Observation.where(name: name),
                 "Test needs name without Observations")
    approved_name = name.approved_name
    # Test must have an Obs of a synonym
    obs = Observation.create(name: approved_name, user: rolf)
    # and synonym must be proposed
    Naming.create(observation: obs, name: obs.name, user: obs.user)

    obss = Name::Observations.new(name)

    assert_blank(
      obss.where_name_proposed,
      "`where_name_proposed` should be blank if only a synonym was proposed"
    )
    assert_blank(
      obss.where_taxon_proposed,
      "`where_taxon_proposed` should be blank " \
      "unless the Name was proposed for another taxon"
    )
  end
end
