# frozen_string_literal: true

require("test_helper")

# Tests of helper module
class ShowNameHelperTest < IntegrationTestCase
  # Prove that all these links appear under "Observations of"
  def test_links_to_observations_of
    login
    # on ShowObservation page
    get("/name/show_name/#{names(:chlorophyllum_rachodes).id}")
    assert_match(:obss_of_this_name.l, response.body)
    assert_match(:taxon_obss_other_names.l, response.body)
    assert_match(:obss_of_taxon.l, response.body)
    assert_match(:obss_taxon_proposed.l, response.body)
    assert_match(:obss_name_proposed.l, response.body)
  end
end
