require "test_helper"

class NameDescriptionIntegrationTest < IntegrationTestCase
  def test_creating_public_description
    # We want to create an empty, default public description for a name that
    # doesn't have any descriptions yet -- simplest possible case.
    @name = Name.find_by(text_name: "Strobilurus diminutivus")
    assert_equal([], @name.descriptions)
    @description_data = {
      source_type: :public,
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
    lurker.check_abilities
  end

  def test_creating_user_description
    # We want to create an empty, default public description for a name that
    # doesn't have any descriptions yet -- simplest possible case.
    @name = Name.find_by(text_name: "Peltigera")
    assert_equal(4, @name.descriptions.length)
    @description_data = {
      source_type: :user,
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
    sess.login!(user)
    sess.click(href: /turn_admin_on/)
    teach_about_name_descriptions(sess)
    sess.user = user
    sess
  end

  def open_normal_session(user)
    sess = open_session
    sess.login!(user)
    teach_about_name_descriptions(sess)
    sess.user = user
    sess
  end

  def open_lurker_session
    sess = open_session
    teach_about_name_descriptions(sess)
    sess.user = nil
    sess
  end

  def teach_about_name_descriptions(sess)
    sess.extend(NameDescriptionDsl)
    sess.abilities = {}
    sess.name_we_are_working_on = @name
    sess.name_description_data = @description_data
    sess.group_expectations = @group_expectations
  end

  ##############################################################################

  module NameDescriptionDsl
    attr_accessor :user
    attr_accessor :abilities
    attr_accessor :name_we_are_working_on
    attr_accessor :name_description_data
    attr_accessor :group_expectations

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
      abilities[:edit].to_s.match(/^visible/)
    end

    def edit_description_requires_login?
      abilities[:edit].to_s.match(/login/)
    end

    def destroy_description_link_there?
      abilities[:destroy].to_s.match(/^visible/)
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
      assert(!UserGroup.reviewers.users.include?(user))
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
      "/names/show_name/#{name.id}"
    end

    def show_name_description_uri
      desc = name_description
      "/names/show_name_description/#{desc.id}"
    end

    def edit_name_description_uri
      desc = name_description
      "/names/edit_name_description/#{desc.id}"
    end

    def destroy_name_description_uri
      desc = name_description
      "/names/destroy_name_description/#{desc.id}"
    end

    def create_name_description
      get(show_name_uri)
      click(href: /create_name_description/)
      # assert_template("names/create_name_description")
      open_form do |form|
        check_name_description_form_defaults(form)
        fill_in_name_description_form(form)
        form.submit
      end
      assert_flash_success
      # assert_template("names/show_name_description")
    end

    def check_name_description_form_defaults(form)
      form.assert_value("source_type", "public")
      form.assert_value("source_name", "")
      form.assert_checked("public_write")
      form.assert_checked("public")
      form.assert_value("notes", "")
      form.assert_enabled("source_type")
      form.assert_enabled("source_name")
      # (have to be enabled because user could switch to :source or :user,
      # instead must use javascript to disable these when :public)
      form.assert_enabled("public_write")
      form.assert_enabled("public")
    end

    def fill_in_name_description_form(form)
      data = name_description_data
      form.change("source_type", data[:source_type])
      form.change("source_name", data[:source_name])
      form.change("public_write", data[:writable])
      form.change("public", data[:readable])
      form.change("gen_desc", data[:gen_desc])
      form.change("diag_desc", data[:diag_desc])
      form.change("look_alikes", data[:look_alikes])
      form.change("notes", data[:notes])
    end

    def check_name_description
      check_name_description_data
      check_name_description_groups
    end

    def check_name_description_data
      desc = name_description
      data = name_description_data
      assert_equal(data[:source_type], desc.source_type)
      assert(data[:source_name] == desc.source_name)
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
      assert_obj_list_equal(data[:admins], desc.admin_groups)
      assert_obj_list_equal(data[:writers], desc.writer_groups)
      assert_obj_list_equal(data[:readers], desc.reader_groups)
      assert_user_list_equal(data[:authors], desc.authors)
      assert_user_list_equal(data[:editors], desc.editors)
    end

    def check_abilities
      get(show_name_uri)
      # Apparently the show_desc link is present
      # even if not allowed to see text.
      # assert_link_exists(show_name_description_uri, can_see_description?)
      assert_link_exists(edit_name_description_uri,
                         edit_description_link_there?)
      assert_link_exists(destroy_name_description_uri,
                         destroy_description_link_there?)
      check_edit_description_link_behavior if edit_description_link_there?
    end

    def check_edit_description_link_behavior
      click(href: edit_name_description_uri)
      if edit_description_requires_login?
        assert_match(%r{account/login}, response.body)
      else
        check_name_description_fields
      end
    end

    def check_name_description_fields
      open_form do |form|
        form.send("assert_#{source_name_field_state}", "source_type")
        form.send("assert_#{source_type_field_state}", "source_name")
        form.send("assert_#{permission_fields_state}", "public_write")
        form.send("assert_#{permission_fields_state}", "public")
      end
    end

    def assert_link_exists(name, val)
      if val
        assert_select("a[href='#{name}']")
      else
        assert_select("a[href='#{name}']", 0)
      end
    end
  end
end
