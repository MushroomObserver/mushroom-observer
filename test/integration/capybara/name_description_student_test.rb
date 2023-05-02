# frozen_string_literal: true

require("test_helper")

# Test typical sessions of university student who is writing descriptions.
class NameDescriptionStudentTest < CapybaraIntegrationTestCase
  # -----------------------------------
  #  Test creating draft for project.
  # -----------------------------------
  def test_creating_drafts
    name = Name.find_by(text_name: "Strobilurus diminutivus")
    gen_desc = "Mary wrote this draft text."

    project = projects(:eol_project)
    project.admin_group.users.delete(mary)

    # admin
    rolf_session    = Capybara::Session.new(:rack_test, Rails.application)
    # creator
    mary_session    = Capybara::Session.new(:rack_test, Rails.application)
    # student
    katrina_session = Capybara::Session.new(:rack_test, Rails.application)
    # user
    dick_session    = Capybara::Session.new(:rack_test, Rails.application)
    # user
    lurker_session  = Capybara::Session.new(:rack_test, Rails.application)

    login(rolf, session: rolf_session)
    login(mary, session: mary_session)
    login(katrina, session: katrina_session)
    login(dick, session: dick_session)

    assert_not_equal(mary_session.driver.request.cookies["mo_user"],
                     dick_session.driver.request.cookies["mo_user"])

    url = create_draft(name, gen_desc, project, session: mary_session)
    check_admin(name, url, gen_desc, project, session: rolf_session)
    check_another_student(url, session: katrina_session)
    check_another_user(url, session: dick_session)
    login(session: lurker_session)
    check_another_user(url, session: lurker_session)
  end

  def create_draft(name, gen_desc, project, session:)
    assert_nil(NameDescription.find_by(gen_desc: gen_desc))
    session.visit("/")
    session.click_link(id: "nav_name_observations_link")
    session.click_link(text: name.text_name)
    url = name_path(name.id)
    session.assert_text("There are no descriptions")
    session.click_link(text: project.title)
    session.assert_text(
      ActionController::Base.helpers.strip_tags(
        :create_name_description_title.t(name: name.display_name)
      )
    )

    # Check that initial form is correct.
    session.within("#name_description_form") do |form|
      assert(form.has_field?("description_source_type",
                             type: :hidden, with: :project))
      assert(form.has_field?("description_source_name",
                             type: :hidden, with: project.title))
      assert(form.has_field?("description_project_id",
                             type: :hidden, with: project.id))
      assert(form.has_unchecked_field?("description_public_write",
                                       disabled: false))
      assert(form.has_unchecked_field?("description_public",
                                       disabled: false))
      form.first("input[type='submit']").click
    end
    assert_flash_success(session: session)
    # assert_template("name/show_name_description")
    marys_draft = NameDescription.last

    # Make sure it shows up on main show_name page and can edit it.
    session.visit("/names/#{name.id}")
    assert(session.has_link?(href: edit_name_description_path(marys_draft.id)))
    # test for a destroy button:
    session.assert_selector(
      class: "destroy_name_description_link_#{marys_draft.id}"
    )

    # Now give it some text to make sure it *can* (but doesn't) actually get
    # displayed (content, that is) on main show_name page.
    session.click_link(href: edit_name_description_path(marys_draft.id))
    session.within("#name_description_form") do |form|
      assert(form.has_field?("description_source_type",
                             type: :hidden, with: :project))
      assert(form.has_field?("description_source_name",
                             type: :hidden, with: project.title))
      assert(form.has_unchecked_field?("description_public_write",
                                       disabled: false))
      assert(form.has_unchecked_field?("description_public",
                                       disabled: false))
      form.fill_in("description_gen_desc", with: gen_desc)
      form.first("input[type='submit']").click
    end
    assert_flash_success(session: session)
    assert_not_nil(NameDescription.find_by(gen_desc: gen_desc))
    url
  end

  # Navigate to show name (no descriptions) and create draft.
  def check_admin(name, url, gen_desc, project, session:)
    session.visit(url)
    # The latest ND should be Mary's draft
    marys_draft = NameDescription.last
    # show n.d link should be restricted
    assert(session.has_link?(href: name_description_path(marys_draft.id),
                             text: /Restricted/))
    assert(session.has_link?(href: edit_name_description_path(marys_draft.id)))
    session.assert_no_text(/#{gen_desc}/)
    assert(session.has_link?(href: new_name_description_path(name.id)))
    session.click_link(href: name_description_path(marys_draft.id))
    assert(session.has_link?(href: edit_name_description_path(marys_draft.id)))
    session.assert_selector(
      class: "destroy_name_description_link_#{marys_draft.id}"
    )
    session.first(:link, href: edit_name_description_path(marys_draft.id)).click
    session.within("#name_description_form") do |form|
      assert(form.has_field?("description_source_type",
                             type: :hidden, with: :project))
      assert(form.has_field?("description_source_name",
                             type: :hidden, with: project.title))
      assert(form.has_unchecked_field?("description_public_write",
                                       disabled: false))
      assert(form.has_unchecked_field?("description_public",
                                       disabled: false))
      assert(form.has_field?("description_gen_desc", with: gen_desc))
    end
  end

  # Can view but not edit.
  def check_another_student(url, session:)
    session.visit(url)
    marys_draft = NameDescription.last
    session.first(:link, href: name_description_path(marys_draft.id)).click
    assert(
      session.has_no_link?(href: edit_name_description_path(marys_draft.id))
    )
    session.assert_no_selector(
      class: "destroy_name_description_link_#{marys_draft.id}"
    )
  end

  # Knows it exists but can't even view it.
  def check_another_user(url, session:)
    session.visit(url)
    marys_draft = NameDescription.last
    assert(session.has_link?(href: name_description_path(marys_draft.id)))
    session.first(:link, href: name_description_path(marys_draft.id)).click
    assert_flash_error(session: session)
  end
end
