# frozen_string_literal: true

require("test_helper")

class ObservationCounterTest < UnitTestCase
  # Name has a direct `name_id` column on observations.
  def test_counts_for_direct_association
    peltigera = names(:peltigera)
    coprinus_comatus = names(:coprinus_comatus)
    expected = {
      peltigera.id => peltigera.observations.count,
      coprinus_comatus.id => coprinus_comatus.observations.count
    }

    assert_equal(expected,
                 ObservationCounter.counts_for([peltigera, coprinus_comatus]))
  end

  # SpeciesList counts through the species_list_observations join
  # table -- no direct column on observations.
  def test_counts_for_through_association
    unknown_list = species_lists(:unknown_species_list)
    first_list = species_lists(:first_species_list)

    # first_list has no observations -- an owner with zero
    # observations gets no entry (inner join), not a 0 entry.
    assert_equal({ unknown_list.id => unknown_list.observations.count },
                 ObservationCounter.counts_for([unknown_list, first_list]))
  end

  def test_empty_owners_returns_empty_hash
    assert_equal({}, ObservationCounter.counts_for([]))
  end
end
