# frozen_string_literal: true

require("test_helper")

# Test adding, editing, and deleting a CollectionNumber
class CollectionNumbersIntegrationTest < CapybaraIntegrationTestCase
  def test_collection_number_remove
    obs = observations(:minimal_unknown_obs)
    assert_not_empty(obs.collection_numbers,
                     "Test needs a fixture with a collection number(s)")
    user = obs.user

    login(user)
    visit(observation_path(obs.id))
    assert_difference("obs.collection_numbers.count", -1) do
      page.find("#observation_collection_numbers").click_on("Remove")
      # new edit form (appears in modal)
      page.find("#content").click_on("Remove")
    end
  end
end
