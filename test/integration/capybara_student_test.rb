# frozen_string_literal: true

require("test_helper")

# Test typical sessions of university student who is writing descriptions.
class CapybaraStudentTest < CapybaraIntegrationTestCase
  # -----------------------------------
  #  Test creating draft for project.
  # -----------------------------------

  def test_creating_drafts
    name = Name.find_by(text_name: "Strobilurus diminutivus")
    gen_desc = "Mary wrote this draft text."

    project = projects(:eol_project)
    project.admin_group.users.delete(mary)

    rolf_session    = Capybara::Session.new(:rack_test, Rails.application)
    mary_session    = Capybara::Session.new(:rack_test, Rails.application)
    katrina_session = Capybara::Session.new(:rack_test, Rails.application)
    dick_session    = Capybara::Session.new(:rack_test, Rails.application)
    lurker_session  = Capybara::Session.new(:rack_test, Rails.application)

    using_session(rolf_session) { login_user(rolf) }
    using_session(mary_session) do
      visit("/account/login")
      binding.break
      assert_field("user_login")

      login_user(mary)
    end
    using_session(katrina_session) { login_user(katrina) }
    using_session(dick_session) { login_user(dick) }

    # assert_not_equal(mary_session.session[:session_id],
    #                  dick_session.session[:session_id])
    # url = mary_session.create_draft(name, gen_desc, project)
    assert_nil(NameDescription.find_by(gen_desc: gen_desc))

    using_session(mary_session) do
      # url = create_draft(name, gen_desc, project)
      visit("/")

      within("#navigation") { click_link("Names") }

      click_link(name.text_name)
      path = current_path
      assert_text(/there are no descriptions/i)

      click_link(project.title)
      assert_text(:create_name_description_title.t(name: name.text_name))

      # binding.break
      # Check that initial form is correct.
      assert_field("description_source_type", type: :hidden, with: :project)
      # has_field?("description_source_name", type: :hidden, with: project.title)
      # has_field?("description_project_id", type: :hidden, with: project.id)
      # has_no_checked_field?("description_public_write", type: :hidden)
      # has_no_checked_field?("description_public", type: :hidden)

      # # click_button("Create") # is not unique, capybara won't click
      # all("input[type=submit][name='commit'][value='Create']")[0].click
      # assert_flash_success
      # assert_template("name/show_name_description")

      # # Make sure it shows up on main show_name page and can edit it.
      # visit(path)
      # assert_link(href: /edit_name_description/)
      # assert_link(href: /destroy_name_description/)

      # # Now give it some text to make sure it *can* (but doesn't) actually get
      # # displayed (content, that is) on main show_name page.
      # click_link(href: /edit_name_description/)
      # has_field?("description_source_type", type: :hidden, with: :project)
      # has_field?("description_source_name", type: :hidden, with: project.title)
      # has_field?("description_project_id", type: :hidden, with: project.id)
      # has_no_checked_field?("description_public_write", type: :hidden)
      # has_no_checked_field?("description_public", type: :hidden)
      # fill_in("description_gen_desc", with: gen_desc)

      # # click_button("Save Edits") # is not unique, capybara won't click
      # all("input[type=submit][name='commit'][value='Save Edits']")[0].click
      # assert_flash_success
    end

    assert_not_nil(NameDescription.find_by(gen_desc: gen_desc))

    # rolf_session.check_admin(url, gen_desc, project)
    # katrina_session.check_another_student(url)
    # dick_session.check_another_user(url)
    # lurker_session.login
    # lurker_session.check_another_user(url)
  end

  module AdminDsl
    def check_admin(url, gen_desc, _project)
      visit(url)
      assert_selector("a[href*=show_name_description]", 1) do |links|
        assert_match(:restricted.l, links.first.to_s)
      end

      assert_no_match(/#{gen_desc}/, response.body)
      assert_selector("a[href*=create_name_description]", 1)
      click_link(href: /show_name_description/)
      assert_selector("a[href*=edit_name_description]")
      assert_selector("a[href*=destroy_name_description]")
      click_link(href: /edit_name_description/)
      # open_form do |form|
      #   form.assert_value("source_type", "project")
      #   form.assert_value("source_name", project.title)
      #   form.assert_value("public_write", false)
      #   form.assert_value("public", false)
      #   form.assert_hidden("source_type")
      #   form.assert_hidden("source_name")
      #   form.assert_enabled("public_write")
      #   form.assert_enabled("public")
      #   form.assert_value("gen_desc", gen_desc)
      # end
    end
  end

  module CreatorDsl
    # Navigate to show name (no descriptions) and create draft.
    def create_draft(_name, _gen_desc, _project)
      visit("/")
      within("#navigation") { click_link("Names") }

      click_link(name.text_name)
      path = current_path
      assert_text(/there are no descriptions/i)

      click_link(project.title)
      assert_text(:create_name_description_title.t(name: name.text_name))

      # Check that initial form is correct.
      has_field?("description_source_type", type: :hidden, with: :project)
      has_field?("description_source_name", type: :hidden, with: project.title)
      has_field?("description_project_id", type: :hidden, with: project.id)
      has_no_checked_field?("description_public_write", type: :hidden)
      has_no_checked_field?("description_public", type: :hidden)

      # click_button("Create") # is not unique, capybara won't click
      all("input[type=submit][name='commit'][value='Create']")[0].click
      assert_flash_success
      assert_template("name/show_name_description")

      # Make sure it shows up on main show_name page and can edit it.
      visit(path)
      assert_link(href: /edit_name_description/)
      assert_link(href: /destroy_name_description/)

      # Now give it some text to make sure it *can* (but doesn't) actually get
      # displayed (content, that is) on main show_name page.
      click_link(href: /edit_name_description/)
      has_field?("description_source_type", type: :hidden, with: :project)
      has_field?("description_source_name", type: :hidden, with: project.title)
      has_field?("description_project_id", type: :hidden, with: project.id)
      has_no_checked_field?("description_public_write", type: :hidden)
      has_no_checked_field?("description_public", type: :hidden)
      fill_in("description_gen_desc", with: gen_desc)

      # click_button("Save Edits") # is not unique, capybara won't click
      all("input[type=submit][name='commit'][value='Save Edits']")[0].click
      assert_flash_success
      # url
    end
  end

  module StudentDsl
    # Can view but not edit.
    def check_another_student(url)
      visit(url)
      click_link(href: /show_name_description/)
      assert_selector("a[href*=edit_name_description]", 0)
      assert_selector("a[href*=destroy_name_description]", 0)
    end
  end

  module UserDsl
    # Knows it exists but can't even view it.
    def check_another_user(url)
      visit(url)
      assert_selector("a[href*=show_name_description]", 1)
      click_link(href: /show_name_description/)

      assert_flash_error
      assert_nil(assigns(:description))
    end
  end
end
