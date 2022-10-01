# frozen_string_literal: true

require("test_helper")
# require("capybara_helper")

# Test adding, editing, and deleting a Sequence
# Uses Capybara; MO SessionFormExtensions don't work on form_with forms
# Use an integration test because click_mo_link needs an id, and
# there's no  id (at least by default) for a form_with resource-oriented
# form field.
class SequencerTest < CapybaraIntegrationTestCase
  def test_sequence
    obs = observations(:detailed_unknown_obs)
    sequence_original_count = Sequence.count

    login(mary)

    visit(observation_path(obs))
    click_on("Add Sequence")
    fill_in("sequence[locus]", with: "New locus")
    click_on("Submit")
    assert_equal(sequence_original_count, Sequence.count,
                 "Sequence without Bases should not have been created")

    fill_in("sequence[bases]", with: "catcatcat")
    click_on("Submit")
    assert_equal(sequence_original_count + 1, Sequence.count,
                 "Sequence should have been created")

    new_sequence = Sequence.last
    new_locus = "Edited Locus"
    find("#observation_sequences").click_link("Edit")
    fill_in("sequence[locus]", with: new_locus)
    fill_in("sequence[bases]", with: "gag gag gag")
    click_on("Submit")
    assert_equal(new_locus, new_sequence.reload.locus,
                 "Sequence should have been updated")

    # Clicking on Destroy Sequence causes Capybara::NotSupportedByDriverError
    # accept_confirm { click_button("Destroy Sequence") }
    # assert(new_sequence.destroyed?, "Sequence should have been destroyed")
  end
end
