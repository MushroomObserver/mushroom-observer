# frozen_string_literal: true

require("test_helper")

# Test typical sessions of university student who is writing descriptions.
class CapybaraStudentTest < IntegrationTestCase
  # -----------------------------------
  #  Test creating draft for project.
  # -----------------------------------

  def test_creating_drafts
    name = Name.find_by(text_name: "Strobilurus diminutivus")
    gen_desc = "Mary wrote this draft text."

    project = projects(:eol_project)
    project.admin_group.users.delete(mary)

    rolf_session    = Capybara::Session.new(:rack_test, Rails.application) # .extend(AdminDsl)
    mary_session    = Capybara::Session.new(:rack_test, Rails.application) # .extend(CreatorDsl)
    katrina_session = Capybara::Session.new(:rack_test, Rails.application) # .extend(StudentDsl)
    dick_session    = Capybara::Session.new(:rack_test, Rails.application) # .extend(UserDsl)
    lurker_session  = Capybara::Session.new(:rack_test, Rails.application) # .extend(UserDsl)

    using_session(rolf_session) { login(as: rolf) }
    using_session(mary_session) { login(as: mary) }
    using_session(katrina_session) { login(as: katrina) }
    using_session(dick_session) { login(as: dick) }

    # assert_not_equal(mary_session.session[:session_id],
    #                  dick_session.session[:session_id])
    # url = mary_session.create_draft(name, gen_desc, project)
    using_session(mary_session) do
      assert_nil(NameDescription.find_by(gen_desc: gen_desc))
      # url = create_draft(name, gen_desc, project)
      visit("/")

      within("#navigation") { click_link("Names") }

      click_link(name.text_name)
      binding.break

      # puts(url)
    end

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
      # can't do this here because assert_nil's not a session method
      # assert_nil(NameDescription.find_by(gen_desc: gen_desc))
      visit("/")

      within("#navigation") { click_link("Names") }

      click_link(label: name.text_name)
      binding.break
      # url = request.url
      # assert_match(/there are no descriptions/i, response.body)
      # click_link(label: project.title)
      # assert_match(:create_name_description_title.t(name: name.display_name),
      #              response.body)

      # Check that initial form is correct.
      # open_form do |form|
      #   form.assert_value("source_type", :project)
      #   form.assert_value("source_name", project.title)
      #   form.assert_value("project_id", project.id)
      #   form.assert_value("public_write", false)
      #   form.assert_value("public", false)
      #   form.assert_hidden("source_type")
      #   form.assert_hidden("source_name")
      #   form.assert_enabled("public_write")
      #   form.assert_enabled("public")
      #   form.submit
      # end
      # assert_flash_success
      # assert_template("name/show_name_description")

      # Make sure it shows up on main show_name page and can edit it.
      # visit(url)
      # assert_selector("a[href*=edit_name_description]", 1)
      # assert_selector("a[href*=destroy_name_description]", 1)

      # Now give it some text to make sure it *can* (but doesn't) actually get
      # displayed (content, that is) on main show_name page.
      # click_link(href: /edit_name_description/)
      # open_form do |form|
      #   form.assert_value("source_type", :project)
      #   form.assert_value("source_name", project.title)
      #   form.assert_value("public_write", false)
      #   form.assert_value("public", false)
      #   form.assert_hidden("source_type")
      #   form.assert_hidden("source_name")
      #   form.assert_enabled("public_write")
      #   form.assert_enabled("public")
      #   form.change("gen_desc", gen_desc)
      #   form.submit
      # end
      # assert_flash_success
      # assert_not_nil(NameDescription.find_by(gen_desc: gen_desc))
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
