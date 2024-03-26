# frozen_string_literal: true

require("test_helper")

module Names
  class DescriptionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def empty_notes
      NameDescription.all_note_fields.index_with do |_field|
        ""
      end
    end

    CREATE_NAME_DESCRIPTION_PARTIALS = %w[
      _fields_for_description
      _textilize_help
      _form
    ].freeze

    SHOW_NAME_DESCRIPTION_PARTIALS = %w[
      _show_description
      _name_description
    ].freeze

    def test_index_default_sort_order
      login
      get(:index)

      assert_displayed_title("Name Descriptions by Name")
    end

    def test_index_sorted_by_user
      login
      get(:index, params: { by: "user" })

      assert_displayed_title("Name Descriptions by User")
    end

    def test_index_by_author_of_one_description
      desc = name_descriptions(:draft_boletus_edulis)
      user = desc.user
      assert_equal(
        1,
        NameDescriptionAuthor.where(user: user).count,
        "Test needs a user who authored exactly one description"
      )

      login
      get(:index, params: { by_author: user })

      assert_redirected_to(/#{name_description_path(desc)}/)
    end

    def test_index_by_author_of_multiple_descriptions
      user = users(:katrina)
      descs_authored_by_user_count =
        NameDescriptionAuthor.where(user: user).count
      assert_operator(
        descs_authored_by_user_count, :>, 1,
        "Test needs a user who authored multiple descriptions"
      )

      login
      get(:index, params: { by_author: user })

      assert_template("index")
      assert_displayed_title("Name Descriptions Authored by #{user.name}")
      assert_select("a:match('href',?)", %r{^/names/descriptions/\d+},
                    { count: descs_authored_by_user_count },
                    "Wrong number of results")
    end

    def test_index_by_author_of_no_descriptions
      user = users(:zero_user)

      login
      get(:index, params: { by_author: user })

      assert_flash_text("No matching name descriptions found.")
      assert_template("index")
    end

    def test_index_by_author_bad_user_id
      bad_user_id = images(:in_situ_image).id
      assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

      login
      get(:index, params: { by_author: bad_user_id })

      assert_flash_text(
        :runtime_object_not_found.l(type: "user", id: bad_user_id)
      )
      assert_redirected_to(name_descriptions_index_path)
    end

    def test_index_by_editor_of_one_description
      desc = name_descriptions(:coprinus_desc)
      user = desc.editors.first
      assert_equal(
        1,
        NameDescriptionEditor.where(user: user).count,
        "Test needs a user who edited exactly one description"
      )

      login
      get(:index, params: { by_editor: user })

      assert_redirected_to(
        %r{/names/descriptions/#{desc.id}}
      )
    end

    def test_index_by_editor_of_multiple_descriptions
      user = users(:mary)
      [name_descriptions(:agaricus_desc),
       name_descriptions(:suillus_desc)].each do |desc|
        desc.editors = [user]
        desc.save
      end
      descs_edited_by_user_count =
        NameDescriptionEditor.where(user: user).count

      login
      get(:index, params: { by_editor: user.id })

      assert_template("index")
      assert_displayed_title("Name Descriptions Edited by #{user.name}")
      assert_select("a:match('href',?)", %r{^/names/descriptions/\d+},
                    { count: descs_edited_by_user_count },
                    "Wrong number of results")
    end

    def test_index_by_editor_of_no_descriptions
      user = users(:zero_user)

      login
      get(:index, params: { by_editor: user.id })

      assert_flash_text("No matching name descriptions found.")
      assert_template("index")
    end

    def test_index_by_editor_bad_user_id
      bad_user_id = images(:in_situ_image).id
      # Above should ensure there's no user with that id. But just in case:
      assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

      login
      get(:index, params: { by_editor: bad_user_id })

      assert_flash_text(
        :runtime_object_not_found.l(type: "user", id: bad_user_id)
      )
      assert_redirected_to(name_descriptions_index_path)
    end

    def test_show_name_description
      desc = name_descriptions(:peltigera_desc)
      params = { "id" => desc.id.to_s }
      login
      get(:show, params: params)
      assert_template("names/descriptions/show")
      assert_template("descriptions/_description_details_and_alts_panel")
    end

    def test_next_description
      description = name_descriptions(:coprinus_comatus_desc)
      id = description.id
      object = NameDescription.find(id)
      params = @controller.find_query_and_next_object(object, :next, id)
      login
      get(:show, params: { flow: :next, id: description.id })
      q = @controller.query_params(QueryRecord.last)
      # from params above
      assert_redirected_to(name_description_path(params[:id], params: q))
    end

    def test_prev_description
      description = name_descriptions(:coprinus_comatus_desc)
      id = description.id
      object = NameDescription.find(id)
      params = @controller.find_query_and_next_object(object, :prev, id)
      login
      get(:show, params: { flow: :prev, id: description.id })
      q = @controller.query_params(QueryRecord.last)
      # from params above
      assert_redirected_to(name_description_path(params[:id], params: q))
    end

    def test_why_danny_cant_edit_lentinus_description
      desc = name_descriptions(:boletus_edulis_desc)
      login
      get(:show, params: { id: desc.id })
      assert_no_flash
      assert_template("names/descriptions/show")
    end

    # This is a bit confusing: create and edit draft are handled here,
    # but PUBLISH draft is handled in the publish controller
    # Create a draft for a project.
    def create_draft_tester(project, name, user = nil, success: true)
      count = NameDescription.count
      params = {
        name_id: name.id,
        source: "project",
        project: project.id
      }
      requires_login(:new, params, user.login)
      if success
        assert_template("names/descriptions/new")
        assert_template("names/descriptions/_form")
      else
        assert_redirected_to(project_path(project.id))
      end
      assert_equal(count, NameDescription.count)
    end

    # Edit a draft for a project (GET).
    def edit_draft_tester(draft, user = nil, success: true, reader: true)
      if user
        assert_not_equal(user, draft.user)
      else
        user = draft.user
      end
      params = {
        id: draft.id
      }
      requires_login(:edit, params, user.login)
      if success
        assert_template("names/descriptions/edit")
        assert_template("names/descriptions/_form")
      elsif reader
        assert_redirected_to(name_description_path(draft.id))
      else
        assert_redirected_to(name_path(draft.name_id))
      end
    end

    # Edit a draft for a project (POST).
    def edit_draft_post_helper(draft, user, params: {}, permission: true,
                               success: true)
      gen_desc = "This is a very general description."
      assert_not_equal(gen_desc, draft.gen_desc)
      diag_desc = "This is a diagnostic description"
      assert_not_equal(diag_desc, draft.diag_desc)
      classification = "Family: _Agaricaceae_"
      assert_not_equal(classification, draft.classification)
      params = {
        id: draft.id,
        description: {
          gen_desc: gen_desc,
          diag_desc: diag_desc,
          classification: classification
        }.merge(params)
      }
      put_requires_login(:update, params, user.login)
      if permission && !success
        assert_template("names/descriptions/edit")
        assert_template("names/descriptions/_form")
      elsif draft.is_reader?(user)
        assert_redirected_to(name_description_path(draft.id))
      else
        assert_redirected_to(name_path(draft.name_id))
      end

      draft.reload
      if permission && success
        assert_equal(gen_desc, draft.gen_desc)
        assert_equal(diag_desc, draft.diag_desc)
        assert_equal(classification, draft.classification)
      else
        assert_not_equal(gen_desc, draft.gen_desc)
        assert_not_equal(diag_desc, draft.diag_desc)
        assert_not_equal(classification, draft.classification)
      end
    end

    def test_create_name_description
      name = names(:peltigera)
      params = { "name_id" => name.id.to_s }
      requires_login(:new, params)
      assert_form_action(action: :create)
    end

    def test_edit_name_description
      desc = name_descriptions(:peltigera_desc)
      params = { "id" => desc.id.to_s }
      requires_login(:edit, params)
      assert_form_action(action: :update)
    end

    # ----------------------------
    #  Test project drafts.
    # ----------------------------

    # Ensure that draft owner can see a draft they own
    def test_show_draft
      draft = name_descriptions(:draft_coprinus_comatus)
      login(draft.user.login)
      get(:show, params: { id: draft.id })
      assert_template("names/descriptions/show")
      assert_template("descriptions/_description_details_and_alts_panel")
    end

    # Ensure that an admin can see a draft they don't own
    def test_show_draft_admin
      draft = name_descriptions(:draft_coprinus_comatus)
      assert_not_equal(draft.user, mary)
      login(mary.login)
      get(:show, params: { id: draft.id })
      assert_template("names/descriptions/show")
      assert_template("descriptions/_description_details_and_alts_panel")
    end

    # Ensure that an member can see a draft they don't own
    def test_show_draft_member
      draft = name_descriptions(:draft_agaricus_campestris)
      assert_not_equal(draft.user, katrina)
      login(katrina.login)
      get(:show, params: { id: draft.id })
      assert_template("names/descriptions/show")
      assert_template("descriptions/_description_details_and_alts_panel")
    end

    # Ensure that a non-member cannot see a draft
    def test_show_draft_non_member
      project = projects(:eol_project)
      draft = name_descriptions(:draft_agaricus_campestris)
      assert(draft.belongs_to_project?(project))
      assert_not(project.member?(dick))
      login(dick.login)
      get(:show, params: { id: draft.id })
      assert_redirected_to(project.show_link_args)
    end

    def test_create_draft_member
      create_draft_tester(projects(:eol_project),
                          names(:coprinus_comatus), katrina)
    end

    def test_create_draft_admin
      create_draft_tester(projects(:eol_project),
                          names(:coprinus_comatus), mary)
    end

    def test_create_draft_not_member
      create_draft_tester(projects(:eol_project),
                          names(:agaricus_campestris), dick, success: false)
    end

    def test_edit_draft
      edit_draft_tester(name_descriptions(:draft_coprinus_comatus))
    end

    def test_edit_draft_admin
      assert(projects(:eol_project).is_admin?(mary))
      assert_equal("EOL Project",
                   name_descriptions(:draft_coprinus_comatus).source_name)
      edit_draft_tester(name_descriptions(:draft_coprinus_comatus), mary)
    end

    def test_edit_draft_member
      assert(projects(:eol_project).member?(katrina))
      assert_equal("EOL Project",
                   name_descriptions(:draft_agaricus_campestris).source_name)
      edit_draft_tester(name_descriptions(:draft_agaricus_campestris),
                        katrina, success: false)
    end

    def test_edit_draft_non_member
      assert_not(projects(:eol_project).member?(dick))
      assert_equal("EOL Project",
                   name_descriptions(:draft_coprinus_comatus).source_name)
      edit_draft_tester(name_descriptions(:draft_coprinus_comatus),
                        dick, success: false, reader: false)
    end

    def test_edit_draft_post_owner
      edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus),
                             rolf)
    end

    def test_edit_draft_post_admin
      edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus),
                             mary)
    end

    def test_edit_draft_post_member
      edit_draft_post_helper(name_descriptions(:draft_agaricus_campestris),
                             katrina, permission: false)
    end

    def test_edit_draft_post_non_member
      edit_draft_post_helper(name_descriptions(:draft_agaricus_campestris),
                             dick, permission: false)
    end

    def test_edit_draft_post_bad_classification
      edit_draft_post_helper(
        name_descriptions(:draft_coprinus_comatus),
        rolf,
        params: { classification: "**Domain**: Eukarya" },
        permission: true,
        success: false
      )
    end

    # ------------------------------
    #  Test creating descriptions.
    # ------------------------------

    def test_create_description_load_form_no_desc_yet
      name = names(:conocybe_filaris)
      assert_equal(0, name.descriptions.length)
      params = { name_id: name.id }

      # Make sure it requires login.
      requires_login(:new, params)
      desc = assigns(:description)
      assert_equal("public", desc.source_type)
      assert_equal("", desc.source_name.to_s)
      assert_equal(true, desc.public)
      assert_equal(true, desc.public_write)

      # Test draft creation by project member.
      login("rolf") # member
      project = projects(:eol_project)
      get(:new, params: params.merge(project: project.id))
      assert_template("names/descriptions/new")
      assert_template("names/descriptions/_form")
      desc = assigns(:description)
      assert_equal("project", desc.source_type)
      assert_equal(project.title, desc.source_name)
      assert_equal(false, desc.public)
      assert_equal(false, desc.public_write)

      # Test draft creation by project non-member.
      login("dick")
      get(:new, params: params.merge(project: project.id))
      assert_redirected_to(project_path(project.id))
      assert_flash_error
    end

    def test_create_description_load_form_already_has_desc
      name = names(:peltigera)
      assert_not_equal(0, name.descriptions.length)
      params = { name_id: name.id }

      # Make sure it requires login.
      requires_login(:new, params)
      desc = assigns(:description)
      assert_equal("public", desc.source_type)
      assert_equal("", desc.source_name.to_s)
      assert_equal(true, desc.public)
      assert_equal(true, desc.public_write)

      # Test draft creation by project member.
      login("katrina") # member
      project = projects(:eol_project)
      get(:new, params: params.merge(project: project.id))
      assert_template("names/descriptions/new")
      assert_template("names/descriptions/_form")
      desc = assigns(:description)
      assert_equal("project", desc.source_type)
      assert_equal(project.title, desc.source_name)
      assert_equal(false, desc.public)
      assert_equal(false, desc.public_write)

      # Test draft creation by project non-member.
      login("dick")
      get(:new, params: params.merge(project: project.id))
      assert_redirected_to(project_path(project.id))
      assert_flash_error

      # Test clone of private description if not reader.
      other = name_descriptions(:peltigera_user_desc)
      login("katrina") # random user
      get(:new, params: params.merge(clone: other.id))
      assert_redirected_to(name_path(name.id))
      assert_flash_error

      # Test clone of private description if can read.
      login("dick") # reader
      get(:new, params: params.merge(clone: other.id))
      assert_template("names/descriptions/new")
      assert_template("names/descriptions/_form")
      desc = assigns(:description)
      assert_equal("user", desc.source_type)
      assert_equal("", desc.source_name.to_s)
      assert_equal(false, desc.public)
      assert_equal(false, desc.public_write)
    end

    def test_create_name_description_public
      name = names(:conocybe_filaris)
      assert_equal(0, name.descriptions.length)

      # Minimum args.
      params = {
        name_id: name.id,
        description: empty_notes.merge(
          source_type: "public",
          source_name: "",
          public: "1",
          public_write: "1"
        )
      }

      post(:create, params: params)
      assert_response(:redirect)
      assert_equal(0, name.descriptions.length)

      # No desc yet -> make new desc default.
      login("dick")
      post(:create, params: params)
      assert_flash_success
      desc = NameDescription.last
      assert_equal(desc.name_id, name.id)
      assert_redirected_to(name_description_path(desc.id))
      name.reload
      assert_objs_equal(desc, name.description)
      assert_obj_arrays_equal([desc], name.descriptions)
      assert_equal("public", desc.source_type)
      assert_equal("", desc.source_name.to_s)
      assert_equal(true, desc.public)
      assert_equal(true, desc.public_write)
      assert_obj_arrays_equal([UserGroup.reviewers], desc.admin_groups)
      assert_obj_arrays_equal([UserGroup.all_users], desc.writer_groups)
      assert_obj_arrays_equal([UserGroup.all_users], desc.reader_groups)

      # Already have default, try to make public desc private -> warn and make
      # public but not default.
      name = names(:coprinus_comatus)
      assert(default = name.description)
      assert_not_equal(0, name.descriptions.length)
      params[:name_id] = name.id
      params[:description][:public]       = "0"
      params[:description][:public_write] = "0"
      params[:description][:source_name]  = "Alternate Description"
      post(:create, params: params)
      assert_flash_warning # tried to make it private
      desc = NameDescription.last
      assert_redirected_to(name_description_path(desc.id))
      name.reload
      assert_objs_equal(default, name.description)
      assert_true(name.descriptions.include?(desc))
      assert_equal("public", desc.source_type)
      assert_equal("Alternate Description", desc.source_name.to_s)
      assert_obj_arrays_equal([UserGroup.reviewers], desc.admin_groups)
      assert_obj_arrays_equal([UserGroup.all_users], desc.writer_groups)
      assert_obj_arrays_equal([UserGroup.all_users], desc.reader_groups)
      assert_equal(true, desc.public)
      assert_equal(true, desc.public_write)
    end

    def test_create_name_description_bogus_classification
      name = names(:agaricus_campestris)
      login("dick")

      bad_class = "*Order*: Agaricales\r\nFamily: Agaricaceae"
      good_class = "Family: Agaricaceae\r\nOrder: Agaricales"
      final_class = "Order: _Agaricales_\r\nFamily: _Agaricaceae_"

      params = {
        name_id: name.id,
        description: empty_notes.merge(
          source_type: "public",
          source_name: "",
          public: "1",
          public_write: "1"
        )
      }

      params[:description][:classification] = bad_class
      post(:create, params: params)
      assert_flash_error
      assert_template("names/descriptions/new")
      assert_template("names/descriptions/_form")

      params[:description][:classification] = good_class
      post(:create, params: params)
      assert_flash_success
      desc = NameDescription.last
      assert_redirected_to(name_description_path(desc.id))

      name.reload
      assert_equal(final_class, name.classification)
      assert_equal(final_class, desc.classification)
    end

    def test_create_name_description_source
      login("dick")

      name = names(:conocybe_filaris)
      assert_nil(name.description)
      assert_equal(0, name.descriptions.length)

      params = {
        name_id: name.id,
        description: empty_notes.merge(
          source_type: "source",
          source_name: "Mushrooms Demystified",
          public: "0",
          public_write: "0"
        )
      }

      post(:create, params: params)
      assert_flash_success
      desc = NameDescription.last
      assert_redirected_to(name_description_path(desc.id))

      name.reload
      assert_nil(name.description)
      assert_true(name.descriptions.include?(desc))
      assert_equal("source", desc.source_type)
      assert_equal("Mushrooms Demystified", desc.source_name)
      assert_false(desc.public)
      assert_false(desc.public_write)
      assert_obj_arrays_equal([UserGroup.one_user(dick)], desc.admin_groups)
      assert_obj_arrays_equal([UserGroup.one_user(dick)], desc.writer_groups)
      assert_obj_arrays_equal([UserGroup.one_user(dick)], desc.reader_groups)
    end

    # Destroy a draft of a project.
    def destroy_draft_helper(draft, user, success: true)
      assert(draft)
      count = NameDescription.count
      params = {
        id: draft.id
      }
      requires_login(:destroy, params, user.login)
      if success
        assert_redirected_to(name_path(draft.name_id))
        assert_raises(ActiveRecord::RecordNotFound) do
          draft = NameDescription.find(draft.id)
        end
        assert_equal(count - 1, NameDescription.count)
      else
        assert(NameDescription.find(draft.id))
        assert_equal(count, NameDescription.count)
        if draft.is_reader?(user)
          assert_redirected_to(name_description_path(draft.id))
        else
          assert_redirected_to(name_path(draft.name_id))
        end
      end
    end

    def test_destroy_draft_owner
      destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), rolf)
    end

    def test_destroy_draft_admin
      destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), mary)
    end

    def test_destroy_draft_member
      destroy_draft_helper(
        name_descriptions(:draft_agaricus_campestris), katrina, success: false
      )
    end

    def test_destroy_draft_non_member
      destroy_draft_helper(
        name_descriptions(:draft_agaricus_campestris), dick, success: false
      )
    end
  end
end
