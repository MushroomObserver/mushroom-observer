# frozen_string_literal: true

require("test_helper")

class CapybaraCuratorTest < CapybaraIntegrationTestCase
  # ---------- Helpers ----------

  def nybg
    herbaria(:nybg_herbarium)
  end

  # ---------- Tests ----------

  def test_first_herbarium_record
    # Mary doesn't have a herbarium.
    obs = observations(:minimal_unknown_obs)
    login!("mary")
    visit("/#{obs.id}")
    assert_selector(id: "observation_details")
    click_on(:create_herbarium_record.t)
    within("#herbarium_record_form") do
      click_commit
    end
    assert_selector(id: "observation_details")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")
  end

  def test_edit_and_remove_herbarium_record_from_show_observation
    login!("mary")
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    visit("/#{obs.id}")
    # binding.break
    first("a[href*='#{edit_herbarium_record_path(rec.id)}']").click
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name",
              with: "This Should Cause It to Reload Form")
      click_commit
    end
    assert_selector("#herbarium_record_form")
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name",
              with: rec.herbarium.name)
      click_commit
    end
    assert_selector(id: "observation_details")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")

    visit("/observations/#{obs.id}/edit")
    click_on(text: "Cancel (Show Observation)")
    assert_selector(id: "observation_details")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")

    # The remove button is a form patch submit, not a link
    within("form[action*='#{
      herbarium_record_remove_observation_path(rec.id)}']") { click_commit }

    assert_selector(id: "observation_details")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_show_herbarium_record
    login!("mary")
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    visit("/#{obs.id}")
    first("a[href*='#{herbarium_record_path(rec.id)}']").click
    assert_selector("body.herbarium_records__show")
    # binding.break
    # click_on(text: "Edit Fungarium Record")
    first("a[href*='#{edit_herbarium_record_path(rec.id)}']").click

    assert_selector("body.herbarium_records__edit")
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name",
              with: "This Should Cause It to Reload Form")
      click_commit
    end
    assert_selector("body.herbarium_records__edit")
    assert_selector("#herbarium_record_form")
    back = current_fullpath
    click_on(text: "Cancel (Show Fungarium Record)")
    assert_selector("body.herbarium_records__show")
    # go_back
    visit(back)
    assert_selector("#herbarium_record_form")
    # binding.break
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name", with: rec.herbarium.name)
      click_commit
    end
    # we're at observations#show ?!
    assert_selector("body.herbarium_records__show")
    click_on(text: "Destroy Fungarium Record")
    assert_selector("body.herbarium_records__index")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_index; end

  def test_index_sort_links; end

  def test_herbarium_index_from_create_herbarium_record; end

  def test_single_herbarium_search; end

  def test_multiple_herbarium_search; end

  def test_herbarium_record_search; end

  def test_herbarium_change_code; end

  def test_herbarium_create_and_destroy; end

  def test_add_curator; end

  def test_curator_request; end

  def test_merge; end
end
