# frozen_string_literal: true

require("test_helper")

class HerbariumCuratorTest < CapybaraIntegrationTestCase
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

    first("a[href*='#{edit_herbarium_record_path(rec.id)}']").click
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name",
              with: "This Should Cause It to Reload Form")
      click_commit
    end
    assert_selector("#herbarium_record_form")
    back = current_fullpath

    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name", with: rec.herbarium.name)
      click_commit
    end
    assert_selector("body.observations__show")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")

    visit(back) # back to edit herbarium record
    click_on(text: "Cancel (Show Observation)")
    assert_selector("body.observations__show")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")

    # The remove button is a rails form patch submit input, not a link
    click_on(class: "remove_herbarium_record_link_#{rec.id}")

    assert_selector("body.observations__show")
    assert_selector("a[href*='#{edit_observation_path(id: obs.id)}']")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_show_herbarium_record
    login!("mary")
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    visit("/#{obs.id}")
    click_link(class: "show_herbarium_record_link_#{rec.id}")

    assert_selector("body.herbarium_records__show")
    click_on(text: "Edit Fungarium Record")

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
    visit(back)

    assert_selector("#herbarium_record_form")
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name", with: rec.herbarium.name)
      click_commit
    end

    assert_selector("body.herbarium_records__show")
    click_on(class: "destroy_herbarium_record_link_#{rec.id}")

    assert_selector("body.herbarium_records__index")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_index
    login!("mary")
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    visit(herbarium_path(rec.herbarium.id))
    assert_selector(
      "a[href*='#{herbarium_records_path(herbarium_id: rec.herbarium.id)}']"
    )
    click_on(id: "herbarium_records_for_herbarium_link")

    assert_selector("body.herbarium_records__index")
    assert_selector("a[href*='#{edit_herbarium_record_path(id: rec.id)}']")
    click_on(id: "edit_herbarium_record_link_#{rec.id}")

    assert_selector("body.herbarium_records__edit")
    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name",
              with: "This Should Cause It to Reload Form")
      click_commit
    end

    assert_selector("body.herbarium_records__edit")
    back = current_fullpath
    click_on(text: "Back to Fungarium Record Index")

    assert_selector("body.herbarium_records__index")
    visit(back)

    within("#herbarium_record_form") do
      fill_in("herbarium_record_herbarium_name", with: rec.herbarium.name)
      click_commit
    end

    assert_selector("body.herbarium_records__index")
    click_on(id: "destroy_herbarium_record_link_#{rec.id}")

    assert_selector("body.herbarium_records__index")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_index_sort_links
    user = users(:zero_user)
    login(user)
    visit(herbaria_path(flavor: :all))
    assert_selector("body.herbaria__index")

    herbaria_show_links = page.all("td > a[id*='show_herbarium_link']")

    assert_equal(
      Herbarium.count, herbaria_show_links.size,
      "Index should have show links to all herbaria"
    )
    # strip query string
    first_herbarium_path = herbaria_show_links.first["href"].sub(/\?.*/, "")
    first("#sorts a", text: "Reverse Order").click

    reverse_herbaria_show_links = page.all("td > a[id*='show_herbarium_link']")

    assert_equal(
      first_herbarium_path,
      reverse_herbaria_show_links.last["href"].sub(/\?.*/, ""),
      "Reverse ordered last herbarium should be the normal first herbarium"
    )
  end

  def test_herbarium_index_from_create_herbarium_record
    obs = observations(:minimal_unknown_obs)
    login!("mary")
    visit(new_herbarium_record_path(observation_id: obs.id))
    click_link(class: "nonpersonal_herbaria_index_link")

    assert_selector("#title", text: :query_title_nonpersonal.l)
  end

  def test_single_herbarium_search
    login
    visit("/")
    within("#pattern_search_form") do
      fill_in("search_pattern", with: "New York")
      select(:HERBARIA.l, from: "search_type")
      click_commit
    end
    assert_selector("#title", text: herbaria(:nybg_herbarium).format_name)
  end

  def test_multiple_herbarium_search
    login
    visit("/")
    within("#pattern_search_form") do
      fill_in("search_pattern", with: "Personal")
      select(:HERBARIA.l, from: "search_type")
      click_commit
    end
    assert_selector("#title", text: "Fungaria Matching ‘Personal’")
  end

  def test_herbarium_record_search
    login
    get("/")
    within("#pattern_search_form") do
      fill_in("search_pattern", with: "Coprinus comatus")
      select(:HERBARIUM_RECORDS.l, from: "search_type")
      click_commit
    end
    assert_selector("body.herbarium_records__index")
    assert_selector("#title",
                    text: "#{:HERBARIUM_RECORDS.l} Matching ‘Coprinus comatus’")
  end

  def test_herbarium_change_code
    herbarium = herbaria(:nybg_herbarium)
    new_code = "NYBG"
    assert_not_equal(new_code, herbarium.code)

    curator = herbarium.curators[0]
    login!(curator.login)
    visit(edit_herbarium_path(herbarium))

    within("#herbarium_form") do
      assert_field("herbarium_code", with: herbarium.code)
      fill_in("herbarium_code", with: new_code)
      click_commit
    end

    assert_equal(new_code, herbarium.reload.code)
    assert_selector("#title", text: herbarium.format_name)
  end

  def test_herbarium_create_and_destroy
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    login!(user.login)
    visit(herbaria_path(flavor: :all))
    click_link(class: "new_herbarium_link")

    within("#herbarium_form") do
      assert_field("herbarium_name")
      assert_field("herbarium_code")
      assert_field("herbarium_place_name")
      assert_field("herbarium_email")
      assert_field("herbarium_mailing_address")
      assert_field("herbarium_description")
      assert_unchecked_field("herbarium_personal")

      fill_in("herbarium_name", with: "Mary's Herbarium")
      check("herbarium_personal")
      click_commit
    end
    user = User.find(user.id)
    assert_not_empty(user.curated_herbaria)

    assert_selector(
      "#title", text: "Mary’s Herbarium" # smart apostrophe
    )
    # Seems like these destroy links don't work with `click_button`
    first(".delete_herbarium_link").click
    assert_selector("#title", text: :herbarium_index.l)
  end

  def test_add_curator
    # Make sure nobody broke the fixtures
    assert(nybg.curators.include?(roy),
           "Need different fixture: herbarium where roy is a curator")
    assert(nybg.curators.exclude?(mary),
           "Need different fixture: herbarium where mary is not a curator")

    # add mary as a curator
    login!(roy.login)
    visit(herbarium_path(nybg))

    within("#herbarium_curators_form") do
      fill_in("add_curator", with: mary.login)
      click_commit
    end

    assert(nybg.curator?(mary),
           "Failed to add mary to curators of #{nybg.format_name}")
    assert_selector("#delete_herbarium_curator_link_#{mary.id}")
  end

  def test_curator_request
    # Make sure noone broke the fixtures
    assert(nybg.curators.exclude?(mary),
           "Need different fixture: herbarium that mary does not curate")

    login!("mary")
    visit(herbarium_path(nybg))

    click_on(id: "new_herbaria_curator_request_link")
    assert_selector("#title", text: :show_herbarium_curator_request.l)

    within("#herbarium_curator_request_form") do
      click_commit
    end

    # UGH. The localized string can't be compared cause of a damn smart quote
    # :show_herbarium_request_sent.t
    assert_flash_text("Request has been sent to admins")
    assert_selector("#title", text: nybg.format_name)
  end

  def test_merge
    fundis = herbaria(:fundis_herbarium)
    assert_true(fundis.owns_all_records?(mary),
                "Need different fixture: #{mary.name} must own all records")
    mary_herbarium = mary.create_personal_herbarium

    login!("mary")
    visit(herbaria_path(flavor: :all))
    click_link(href: herbaria_path(merge: fundis))
    within("form[action *= 'dest=#{mary_herbarium.id}']") do
      click_commit
    end

    assert_flash_success # Rails follows the redirect
    assert_selector("#title", text: mary_herbarium.format_name)
  end
end
