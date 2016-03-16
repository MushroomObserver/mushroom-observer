# encoding: utf-8

require "test_helper"

class CuratorTest < IntegrationTestCase
  def test_first_specimen
    # Mary doesn't have a herbarium.
    sess = login!("mary", "testpassword", true)
    sess.get("/1")
    sess.assert_template("observer/show_observation")
    sess.click(label: :show_observation_create_specimen.t)
    sess.assert_template("specimen/add_specimen")
    sess.open_form do |form|
      form.submit("Add")
    end
    sess.assert_template("herbarium/edit_herbarium")
  end

  def test_herbarium_index_from_add_specimen
    sess = login!("mary", "testpassword", true)
    sess.get("/specimen/add_specimen/1")
    sess.click(label: :herbarium_index.t)
    sess.assert_template("herbarium/index")
  end

  def test_single_herbarium_search
    sess = open_session
    sess.get("/")
    sess.open_form("form[action*=search]") do |form|
      form.change("pattern", "New York")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    sess.assert_template("herbarium/show_herbarium")
  end

  def test_multiple_herbarium_search
    sess = open_session
    sess.get("/")
    sess.open_form("form[action*=search]") do |form|
      form.change("pattern", "Personal")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    sess.assert_template("herbarium/list_herbaria")
  end

  def test_specimen_search
    sess = open_session
    sess.get("/")
    sess.open_form("form[action*=search]") do |form|
      form.change("pattern", "Coprinus comatus")
      form.select("type", :SPECIMENS.l)
      form.submit("Search")
    end
    sess.assert_template("specimen/list_specimens")
  end

  def test_herbarium_change_code
    herbarium = herbaria(:nybg_herbarium)
    new_code = "NYBG"
    assert_not_equal(new_code, herbarium.code)
    curator = herbarium.curators[0]
    sess = login!(curator.login, "testpassword", true)
    sess.get("/herbarium/edit_herbarium?id=#{herbarium.id}")
    sess.open_form do |form|
      form.assert_value("code", herbarium.code)
      form.change("code", new_code)
      form.submit(:edit_herbarium_save.t)
    end
    herbarium = Herbarium.find(herbarium.id)
    sess.assert_equal(new_code, herbarium.code)
    sess.assert_template("herbarium/show_herbarium")
  end

  def test_herbarium_create
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    sess = login!(user.login, "testpassword", true)
    sess.get("/herbarium/create_herbarium")
    sess.open_form do |form|
      form.assert_value("herbarium_name", user.personal_herbarium_name)
      form.assert_value("code", "")
      form.assert_value("description", "")
      form.assert_value("email", user.email)
      form.assert_value("mailing_address", "")
      form.assert_value("place_name", "")
      form.submit(:create_herbarium_add.t)
    end
    user = User.find(user.id)
    sess.assert_not_equal([], user.curated_herbaria)
    sess.assert_template("herbarium/show_herbarium")
  end
end
