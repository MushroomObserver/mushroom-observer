# frozen_string_literal: true

require("test_helper")

# Tests of helper module
class ShowNameHelperTest < CapybaraIntegrationTestCase
  # Prove that all these links appear under "Observations of"
  def test_links_to_observations_of
    login
    # on ShowObservation page
    visit("/names/#{names(:chlorophyllum_rachodes).id}")
    assert_text(:obss_of_this_name.l)
    assert_text(:taxon_obss_other_names.l)
    assert_text(:obss_of_taxon.l)
    assert_text(:obss_taxon_proposed.l)
    assert_text(:obss_name_proposed.l)
  end
end
