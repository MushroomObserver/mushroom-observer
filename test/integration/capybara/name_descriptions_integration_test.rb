# frozen_string_literal: true

require("test_helper")

class NameDescriptionsIntegrationTest < CapybaraIntegrationTestCase
  # -----------------------------------
  #  Test student creating draft for project.
  #  This could be refactored to use the methods from the second test?
  # -----------------------------------

  def test_creating_drafts
    name = Name.find_by(text_name: "Strobilurus diminutivus")
    gen_desc = "Mary wrote this draft text."

    project = projects(:eol_project)
    project.admin_group.users.delete(mary)

    rolf_session    = open_session # admin
    mary_session    = open_session # creator
    katrina_session = open_session # student
    dick_session    = open_session # user
    lurker_session  = open_session # user

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

  # end of student test
  #################################################################

  def test_creating_public_description
    # We want to create an empty, default public description for a name that
    # doesn't have any descriptions yet -- simplest possible case.
    @name = Name.find_by(text_name: "Strobilurus diminutivus")
    assert_equal([], @name.descriptions)
    @description_data = {
      source_type: "public",
      source_name: nil,
      readable: true,
      writable: true,
      notes: "I like this mushroom."
    }
    @group_expectations = {
      admins: [UserGroup.reviewers],
      writers: [UserGroup.all_users],
      readers: [UserGroup.all_users],
      authors: [],
      editors: [mary]
    }

    admin = open_admin_session(dick)
    reviewer = open_normal_session(rolf)
    owner = open_normal_session(mary)
    random_user = open_normal_session(katrina)
    lurker = open_lurker_session

    reviewer.should_be_reviewer
    owner.should_not_be_reviewer
    random_user.should_not_be_reviewer

    # sets (not checks) the abilities
    admin.should_be_able_to_do_anything
    reviewer.should_be_able_to_do_anything_but_change_permissions
    owner.should_be_able_to_edit_and_change_name
    random_user.should_be_able_to_edit_text_only
    lurker.should_be_able_to_see_but_needs_to_login

    owner.create_name_description
    owner.check_name_description

    admin.check_abilities
    reviewer.check_abilities
    owner.check_abilities
    random_user.check_abilities
    lurker.shouldnt_be_able_to_do_anything
  end

  def test_creating_user_description
    # We want to create an empty, default public description for a name that
    # doesn't have any descriptions yet -- simplest possible case.
    @name = Name.find_by(text_name: "Peltigera")
    assert_equal(4, @name.descriptions.length)
    @description_data = {
      source_type: "user",
      source_name: "Mary's Corner",
      readable: true,
      writable: false,
      gen_desc: "Leafy felt lichens.",
      diag_desc: "Usually with veins and tomentum below.",
      look_alikes: "_Solorina_ maybe, but not much else."
    }
    @group_expectations = {
      admins: [UserGroup.one_user(mary)],
      writers: [UserGroup.one_user(mary)],
      readers: [UserGroup.all_users],
      authors: [mary],
      editors: []
    }

    admin = open_admin_session(dick)
    reviewer = open_normal_session(rolf)
    owner = open_normal_session(mary)
    random_user = open_normal_session(katrina)
    lurker = open_lurker_session

    reviewer.should_be_reviewer
    owner.should_not_be_reviewer
    random_user.should_not_be_reviewer

    admin.should_be_able_to_do_anything
    reviewer.shouldnt_be_able_to_do_anything
    owner.should_be_able_to_do_anything
    random_user.shouldnt_be_able_to_do_anything
    lurker.shouldnt_be_able_to_do_anything

    owner.create_name_description
    owner.check_name_description

    admin.check_abilities
    reviewer.check_abilities
    owner.check_abilities
    random_user.check_abilities
    lurker.check_abilities
  end

  def open_admin_session(user)
    user.admin = true
    user.save
    sess = open_session
    login!(user, session: sess)
    sess.first(:button, id: "user_nav_admin_mode_link").click
    teach_about_name_descriptions(sess)
    sess.user = user # can't assign props to session with capybara?
    sess
  end

  def open_normal_session(user)
    sess = open_session
    login!(user, session: sess)
    teach_about_name_descriptions(sess)
    sess.user = user # can't assign props to session with capybara?
    sess
  end

  def open_lurker_session
    sess = open_session
    teach_about_name_descriptions(sess)
    sess.user = nil # can't assign props to session with capybara
    sess
  end

  def teach_about_name_descriptions(sess)
    sess.extend(NameDescriptionDsl)
    sess.abilities = {}
    sess.assertions = 0
    sess.name_we_are_working_on = @name
    sess.name_description_data = @description_data
    sess.group_expectations = @group_expectations
  end

  ##############################################################################
  # NOTE: When you extend the session with a module, you don't get anything
  # but the Capybara::Session methods for free (unlike in rails-dom-testing).
  # You have to manually include any classes that are otherwise available to
  # this test via inheritance. Also, Minitest::Assertions requires adding the
  # attr_accessor :assertions, an incrementable integer.

  module NameDescriptionDsl
    include Minitest::Assertions
    include CapybaraSessionExtensions
    include GeneralExtensions
    attr_accessor :user, :abilities, :name_we_are_working_on,
                  :name_description_data, :group_expectations,
                  :assertions # needed by Minitest::Assertions

    def show_description_link_should_be(val)
      abilities[:show] = val
    end

    def edit_description_link_should_be(val)
      abilities[:edit] = val
    end

    def destroy_description_link_should_be(val)
      abilities[:destroy] = val
    end

    def source_name_field_should_be(val)
      abilities[:source_name] = val
    end

    def source_type_field_should_be(val)
      abilities[:source_type] = val
    end

    def permission_fields_should_be(val)
      abilities[:permissions] = val
    end

    def can_see_description?
      abilities[:show] == :visible
    end

    def edit_description_link_there?
      abilities[:edit].to_s.start_with?("visible")
    end

    def edit_description_requires_login?
      abilities[:edit].to_s.include?("login")
    end

    def destroy_description_link_there?
      abilities[:destroy].to_s.start_with?("visible")
    end

    def source_name_field_state
      abilities[:source_name]
    end

    def source_type_field_state
      abilities[:source_type]
    end

    def permission_fields_state
      abilities[:permissions]
    end

    def should_be_reviewer
      assert(UserGroup.reviewers.users.include?(user))
    end

    def should_not_be_reviewer
      assert(UserGroup.reviewers.users.exclude?(user))
    end

    def should_be_able_to_do_anything
      show_description_link_should_be(:visible)
      edit_description_link_should_be(:visible_and_work)
      destroy_description_link_should_be(:visible)
      source_name_field_should_be(:enabled)
      source_type_field_should_be(:enabled)
      permission_fields_should_be(:enabled)
    end

    def should_be_able_to_do_anything_but_change_permissions
      show_description_link_should_be(:visible)
      edit_description_link_should_be(:visible_and_work)
      destroy_description_link_should_be(:visible)
      source_name_field_should_be(:hidden)
      source_type_field_should_be(:enabled)
      permission_fields_should_be(:disabled)
    end

    def should_be_able_to_edit_and_change_name
      show_description_link_should_be(:visible)
      edit_description_link_should_be(:visible_and_work)
      destroy_description_link_should_be(:absent)
      source_name_field_should_be(:no_field)
      source_type_field_should_be(:enabled)
      permission_fields_should_be(:disabled)
    end

    def should_be_able_to_edit_text_only
      show_description_link_should_be(:visible)
      edit_description_link_should_be(:visible_and_work)
      destroy_description_link_should_be(:absent)
      source_name_field_should_be(:no_field)
      source_type_field_should_be(:no_field)
      permission_fields_should_be(:no_field)
    end

    def should_be_able_to_see_but_needs_to_login
      show_description_link_should_be(:visible)
      edit_description_link_should_be(:visible_but_require_login)
      destroy_description_link_should_be(:absent)
      source_name_field_should_be(:na)
      source_type_field_should_be(:na)
      permission_fields_should_be(:na)
    end

    def shouldnt_be_able_to_do_anything
      show_description_link_should_be(:absent)
      edit_description_link_should_be(:absent)
      destroy_description_link_should_be(:absent)
      source_name_field_should_be(:na)
      source_type_field_should_be(:na)
      permission_fields_should_be(:na)
    end

    def name_description
      @name_description ||= NameDescription.last
    end

    def show_name_uri
      name = name_we_are_working_on
      "/names/#{name.id}"
    end

    def show_name_description_uri
      desc = name_description
      "/names/descriptions/#{desc.id}"
    end

    def new_name_description_uri
      name = name_we_are_working_on
      "/names/#{name.id}/descriptions/new"
    end

    def edit_name_description_uri
      desc = name_description
      "/names/descriptions/#{desc.id}/edit"
    end

    def destroy_name_description_uri
      desc = name_description
      "/names/descriptions/#{desc.id}"
    end

    def create_name_description
      visit(show_name_uri)
      click_link(href: new_name_description_uri)
      assert_selector("body.descriptions__new")
      within("#name_description_form") do |form|
        check_name_description_form_defaults(form)
        fill_in_name_description_form(form)
        form.first(:button, type: "submit").click
      end
      assert_flash_success(session: self)
      assert_selector("body.descriptions__show")
    end

    def check_name_description_form_defaults(form)
      assert(form.has_field?("description_source_type",
                             with: :public, disabled: false))
      assert(form.has_field?("description_source_name",
                             text: "", disabled: false))
      # (have to be enabled because user could switch to :source or :user,
      #  instead must use javascript to disable these when "public")
      assert(form.has_checked_field?("description_public_write",
                                     disabled: false))
      assert(form.has_checked_field?("description_public", disabled: false))
      assert(form.has_field?("description_notes", text: ""))
    end

    def fill_in_name_description_form(form)
      data = name_description_data
      # form.select(value: data[:source_type], from: "description_source_type")
      form.find_field("description_source_type").
        find("option[value='#{data[:source_type]}']").select_option
      form.fill_in("description_source_name", with: data[:source_name])
      if data[:writable]
        form.check("description_public_write")
      else
        form.uncheck("description_public_write")
      end
      if data[:readable]
        form.check("description_public")
      else
        form.uncheck("description_public")
      end
      form.fill_in("description_gen_desc", with: data[:gen_desc])
      form.fill_in("description_diag_desc", with: data[:diag_desc])
      form.fill_in("description_look_alikes", with: data[:look_alikes])
      form.fill_in("description_notes", with: data[:notes])
    end

    def check_name_description
      check_name_description_data
      check_name_description_groups
    end

    def check_name_description_data
      desc = name_description
      data = name_description_data
      assert_equal(data[:source_type], desc.source_type)
      assert_equal(data[:source_name].to_s, desc.source_name)
      assert_equal(data[:writable], desc.public_write)
      assert_equal(data[:readable], desc.public)
      assert_equal(data[:gen_desc].to_s, desc.gen_desc.to_s)
      assert_equal(data[:diag_desc].to_s, desc.diag_desc.to_s)
      assert_equal(data[:look_alikes].to_s, desc.look_alikes.to_s)
      assert_equal(data[:notes].to_s, desc.notes.to_s)
    end

    def check_name_description_groups
      desc = name_description
      data = group_expectations
      assert_obj_arrays_equal(data[:admins], desc.admin_groups)
      assert_obj_arrays_equal(data[:writers], desc.writer_groups)
      assert_obj_arrays_equal(data[:readers], desc.reader_groups)
      assert_user_arrays_equal(data[:authors], desc.authors)
      assert_user_arrays_equal(data[:editors], desc.editors)
    end

    def check_abilities
      visit(show_name_uri)
      # Apparently the show_desc link is present
      # even if not allowed to see text.
      # assert_link_exists(show_name_description_uri, can_see_description?)
      assert_link_exists(edit_name_description_uri,
                         edit_description_link_there?)
      assert_form_exists(destroy_name_description_uri,
                         destroy_description_link_there?)
      check_edit_description_link_behavior if edit_description_link_there?
    end

    def check_edit_description_link_behavior
      click_link(href: edit_name_description_uri)
      if edit_description_requires_login?
        assert_text(%r{account/login/new})
      else
        check_name_description_fields
      end
    end

    # This is a convoluted little test. We're not checking for enabled fields;
    # the form may not print with these fields at all. But that's how the o
    # original test was written. It only **refuted** the presence of a disabled
    # field. (In other words, !! !== ==)
    def check_name_description_fields
      within("#name_description_form") do |form|
        if source_type_field_state == :disabled
          assert(form.has_field?("description_source_type", disabled: true))
        else
          assert(form.has_no_field?("description_source_type", disabled: true))
        end
        if permission_fields_state == :disabled
          assert(form.has_field?("description_public_write", disabled: true))
          assert(form.has_field?("description_public", disabled: true))
        else
          assert(form.has_no_field?("description_public_write", disabled: true))
          assert(form.has_no_field?("description_public", disabled: true))
        end
      end
    end

    def assert_link_exists(uri, val)
      if val
        assert(has_link?(href: /#{uri}/))
      else
        assert(has_no_link?(href: /#{uri}/))
      end
    end

    def assert_form_exists(uri, val)
      if val
        assert_selector("form[action*='#{uri}']")
      else
        assert_no_selector("form[action*='#{uri}']")
      end
    end
  end
end
