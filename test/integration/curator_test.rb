require "test_helper"

class CuratorTest < IntegrationTestCase
  def test_first_herbarium_record
    # Mary doesn't have a herbarium.
    obs = observations(:minimal_unknown_obs)
    login!("mary", "testpassword", true)
    get("/#{obs.id}")
    assert_template("observer/show_observation")
    click(label: :create_herbarium_record.t)
    assert_template("herbarium_record/create_herbarium_record")
    open_form do |form|
      form.submit("Add")
    end
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
  end

  def test_edit_and_remove_herbarium_record_from_show_observation
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.select { |r| r.can_edit?(mary) }.first
    get("/#{obs.id}")
    click(href: "/herbarium_record/edit_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    go_back
    click(label: "Cancel (Show Observation)")
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    click(href: "/herbarium_record/remove_observation/#{rec.id}")
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    assert(!obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_show_herbarium_record
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.select { |r| r.can_edit?(mary) }.first
    get("/#{obs.id}")
    click(href: "/herbarium_record/show_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/show_herbarium_record")
    click(label: "Edit Herbarium Record")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    click(label: "Cancel (Show Herbarium Record)")
    assert_template("herbarium_record/show_herbarium_record")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_record/show_herbarium_record")
    click(label: "Destroy Herbarium Record")
    assert_template("herbarium_record/list_herbarium_records")
    assert(!obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_index
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.select { |r| r.can_edit?(mary) }.first
    get("/herbarium/show_herbarium/#{rec.herbarium.id}")
    click(href: /herbarium_index/)
    assert_template("herbarium_record/list_herbarium_records")
    click(href: "/herbarium_record/edit_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    click(label: "Back to Herbarium Record Index")
    assert_template("herbarium_record/list_herbarium_records")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_record/list_herbarium_records")
    click(href: "/herbarium_record/destroy_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/list_herbarium_records")
    assert(!obs.reload.herbarium_records.include?(rec))
  end

  def test_herbarium_index_from_create_herbarium_record
    login!("mary", "testpassword", true)
    get("/herbarium_record/create_herbarium_record/" +
        observations(:minimal_unknown_obs).id.to_s)
    click(label: :herbarium_index.t)
    assert_template("herbarium/list_herbaria")
  end

  def test_single_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "New York")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_template("herbarium/show_herbarium")
  end

  def test_multiple_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Personal")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_template("herbarium/list_herbaria")
  end

  def test_herbarium_record_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Coprinus comatus")
      form.select("type", :HERBARIUM_RECORDS.l)
      form.submit("Search")
    end
    assert_template("herbarium_record/list_herbarium_records")
  end

  def test_herbarium_change_code
    herbarium = herbaria(:nybg_herbarium)
    new_code = "NYBG"
    assert_not_equal(new_code, herbarium.code)
    curator = herbarium.curators[0]
    login!(curator.login, "testpassword", true)
    get("/herbarium/edit_herbarium?id=#{herbarium.id}")
    open_form do |form|
      form.assert_value("code", herbarium.code)
      form.change("code", new_code)
      form.submit(:SAVE.t)
    end
    herbarium = Herbarium.find(herbarium.id)
    assert_equal(new_code, herbarium.code)
    assert_template("herbarium/show_herbarium")
  end

  def test_herbarium_create
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    login!(user.login, "testpassword", true)
    get("/herbarium/create_herbarium")
    open_form do |form|
      form.assert_value("herbarium_name", "")
      form.assert_value("code", "")
      form.assert_value("place_name", "")
      form.assert_value("email", "")
      form.assert_value("mailing_address", "")
      form.assert_value("description", "")
      form.assert_unchecked("personal")
      form.change("herbarium_name", "Mary's Herbarium")
      form.check("personal")
      form.submit(:CREATE.t)
    end
    user = User.find(user.id)
    assert_not_empty(user.curated_herbaria)
    assert_template("herbarium/show_herbarium")
  end
end
