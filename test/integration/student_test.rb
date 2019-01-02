require "test_helper"

# Test typical sessions of university student who is writing descriptions.
class StudentTest < IntegrationTestCase
  # -----------------------------------
  #  Test creating draft for project.
  # -----------------------------------

  def test_creating_drafts
    name = Name.find_by(text_name: "Strobilurus diminutivus")
    gen_desc = "Mary wrote this draft text."

    project = projects(:eol_project)
    project.admin_group.users.delete(mary)

    app = open_session.app
    rolf_session    = open_session.extend(AdminDsl)
    mary_session    = open_session.extend(CreatorDsl)
    katrina_session = open_session.extend(StudentDsl)
    dick_session    = open_session.extend(UserDsl)
    lurker_session  = open_session.extend(UserDsl)

    rolf_session.login!(rolf)
    mary_session.login!(mary)
    katrina_session.login!(katrina)
    dick_session.login!(dick)

    refute_equal(mary_session.session[:session_id],
                 dick_session.session[:session_id])
    url = mary_session.create_draft(name, gen_desc, project)
    rolf_session.check_admin(url, gen_desc, project)
    katrina_session.check_another_student(url)
    dick_session.check_another_user(url)
    lurker_session.check_another_user(url)
  end

  module AdminDsl
    def check_admin(url, gen_desc, project)
      get(url)
      assert_select("a[href*=show_name_description]", 1) do |links|
        assert_match(:restricted.l, links.first.to_s)
      end
      refute_match(/#{gen_desc}/, response.body)
      assert_select("a[href*=create_name_description]", 1)
      click(href: /show_name_description/)
      assert_select("a[href*=edit_name_description]")
      assert_select("a[href*=destroy_name_description]")
      click(href: /edit_name_description/)
      open_form do |form|
        form.assert_value("source_type", "project")
        form.assert_value("source_name", project.title)
        form.assert_value("public_write", false)
        form.assert_value("public", false)
        form.assert_hidden("source_type")
        form.assert_hidden("source_name")
        form.assert_enabled("public_write")
        form.assert_enabled("public")
        form.assert_value("gen_desc", gen_desc)
      end
    end
  end

  module CreatorDsl
    # Navigate to show name (no descriptions) and create draft.
    def create_draft(name, gen_desc, project)
      assert_nil(NameDescription.find_by_gen_desc(gen_desc))
      get("/")
      click(label: "Names", in: :left_panel)
      click(label: name.text_name)
      url = request.url
      assert_match(/there are no descriptions/i, response.body)
      click(label: project.title)
      assert_match(:create_name_description_title.t(name: name.display_name),
                   response.body)

      # Check that initial form is correct.
      open_form do |form|
        form.assert_value("source_type", :project)
        form.assert_value("source_name", project.title)
        form.assert_value("project_id", project.id)
        form.assert_value("public_write", false)
        form.assert_value("public", false)
        form.assert_hidden("source_type")
        form.assert_hidden("source_name")
        form.assert_enabled("public_write")
        form.assert_enabled("public")
        form.submit
      end
      assert_flash_success
      # assert_template("name/show_name_description")

      # Make sure it shows up on main show_name page and can edit it.
      get(url)
      assert_select("a[href*=edit_name_description]", 1)
      assert_select("a[href*=destroy_name_description]", 1)

      # Now give it some text to make sure it *can* (but doesn't) actually get
      # displayed (content, that is) on main show_name page.
      click(href: /edit_name_description/)
      open_form do |form|
        form.assert_value("source_type", :project)
        form.assert_value("source_name", project.title)
        form.assert_value("public_write", false)
        form.assert_value("public", false)
        form.assert_hidden("source_type")
        form.assert_hidden("source_name")
        form.assert_enabled("public_write")
        form.assert_enabled("public")
        form.change("gen_desc", gen_desc)
        form.submit
      end
      assert_flash_success
      assert_not_nil(NameDescription.find_by_gen_desc(gen_desc))
      url
    end
  end

  module StudentDsl
    # Can view but not edit.
    def check_another_student(url)
      get(url)
      click(href: /show_name_description/)
      assert_select("a[href*=edit_name_description]", 0)
      assert_select("a[href*=destroy_name_description]", 0)
    end
  end

  module UserDsl
    # Knows it exists but can't even view it.
    def check_another_user(url)
      get(url)
      assert_select("a[href*=show_name_description]", 1)
      click(href: /show_name_description/)
      assert_flash_error
      assert_nil(assigns(:description))
    end
  end
end
