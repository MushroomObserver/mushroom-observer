require "test_helper"

# Tests of helper module
class ShowNameHelperTest < IntegrationTestCase
  def test_deserialize
    get("/name/show_name/#{names(:chlorophyllum_rachodes).id}")
    assert_match(:obss_of_this_name.l, response.body)
    assert_match(:taxon_obss_other_names.l, response.body)
    assert_match(:obss_of_taxon.l, response.body)
    assert_match(:obss_name_proposed.l, response.body)
    assert_match(:obss_taxon_proposed.l, response.body)

    get("/#{observations(:chlorophyllum_rachodes_obs).id}")
    assert_match(:show_observation_alternative_names.l, response.body)
  end
end
