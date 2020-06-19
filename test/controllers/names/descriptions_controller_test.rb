require "test_helper"

class Names::DescriptionsControllerTest < IntegrationControllerTest

  # This section copied from NamesControllerTest
  def self.report_email(email)
    @@emails << email
  end

  def setup
    @new_pts  = 10
    @chg_pts  = 10
    @auth_pts = 100
    @edit_pts = 10
    @@emails = []
    super
  end

  def empty_notes
    Name::Description.all_note_fields.each_with_object({}) do |field, result|
      result[field] = ""
    end
  end

  CREATE_NAME_DESCRIPTION_PARTIALS = %w[
    _form_description
    _textilize_help
    _form_name_description
  ].freeze

  SHOW_NAME_DESCRIPTION_PARTIALS = %w[
    _show_description
    _name_description
  ].freeze

  # Create a draft for a project.
  def create_draft_tester(project, name, user = nil, success = true)
    count = Name::Description.count
    params = {
      id: name.id,
      source: "project",
      project: project.id
    }
    requires_login(:new, params, user.login)
    if success
      assert_template(:new, partial: "_form_name_description")
    else
      assert_redirected_to(project_path(id: project.id))
    end
    assert_equal(count, Name::Description.count)
  end

  # Edit a draft for a project (GET).
  def edit_draft_tester(draft, user = nil, success = true, reader = true)
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
      assert_template(:edit, partial: "_form_name_description")
    elsif reader
      assert_redirected_to(name_description_path(id: draft.id))
    else
      assert_redirected_to(name_path(id: draft.name_id))
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
    post_requires_login(:edit, params, user.login)
    if permission && !success
      assert_template(:edit,
                      partial: "_form_name_description")
    elsif draft.is_reader?(user)
      assert_redirected_to(name_description_path(id: draft.id))
    else
      assert_redirected_to(name_path(id: draft.name_id))
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

  def publish_draft_helper(draft, user = nil, merged = true, conflict = false)
    if user
      assert_not_equal(draft.user, user)
    else
      user = draft.user
    end
    draft_gen_desc = draft.gen_desc
    name_gen_desc = begin
                      draft.name.description.gen_desc
                    rescue StandardError
                      nil
                    end
    same_gen_desc = (draft_gen_desc == name_gen_desc)
    name_id = draft.name_id
    params = {
      id: draft.id
    }
    requires_login(:publish_description, params, user.login)
    name = Name.find(name_id)
    new_gen_desc = begin
                     name.description.gen_desc
                   rescue StandardError
                     nil
                   end
    if merged
      assert_equal(draft_gen_desc, new_gen_desc)
    else
      assert_equal(same_gen_desc, draft_gen_desc == new_gen_desc)
      assert(Name::Description.safe_find(draft.id))
    end
    if conflict
      assert_template(:edit, partial: true)
      assert(assigns(:description).gen_desc.index(draft_gen_desc))
      assert(assigns(:description).gen_desc.index(name_gen_desc))
    else
      assert_redirected_to(name_path(id: name_id))
    end
  end

  def make_description_default_helper(desc)
    user = desc.user
    params = {
      id: desc.id
    }
    requires_login(:make_description_default, params, user.login)
  end

  # Destroy a draft of a project.
  def destroy_draft_helper(draft, user, success = true)
    assert(draft)
    count = Name::Description.count
    params = {
      id: draft.id
    }
    requires_login(:destroy, params, user.login)
    if success
      assert_redirected_to(name_path(id: draft.name_id))
      assert_raises(ActiveRecord::RecordNotFound) do
        draft = Name::Description.find(draft.id)
      end
      assert_equal(count - 1, Name::Description.count)
    else
      assert(Name::Description.find(draft.id))
      assert_equal(count, Name::Description.count)
      if draft.is_reader?(user)
        assert_redirected_to(name_description_path(id: draft.id))
      else
        assert_redirected_to(name_path(id: draft.name_id))
      end
    end
  end

  def assert_email_generated
    assert_not_empty(@@emails, "Was expecting an email notification.")
  ensure
    @@emails = []
  end

  def assert_no_emails
    msg = @@emails.join("\n")
    assert(@@emails.empty?,
           "Wasn't expecting any email notifications; got:\n#{msg}")
  ensure
    @@emails = []
  end

  def test_name_description_index
    get name_descriptions_path
    assert_template(:index)
  end

  def test_index_description_index
    get(:index_name_description)
    assert_template(:index)
  end

  def test_observation_index
    get(:observation_index)
    assert_template(:index)
  end

  def test_observation_index_by_letter
    get(:observation_index, letter: "A")
    assert_template(:index)
  end

  def test_show_next
    description = name_descriptions(:coprinus_comatus_desc)
    id = description.id
    object = Name::Description.find(id)
    params = @controller.find_query_and_next_object(object, :next, id)
    get name_descriptions_show_next_path(id: description.id)
    q = @controller.query_params(QueryRecord.last)
    assert_redirected_to(
      name_description_path(id: params[:id], params: q)
    )
  end

  def test_show_prev
    description = name_descriptions(:coprinus_comatus_desc)
    id = description.id
    object = Name::Description.find(id)
    params = @controller.find_query_and_next_object(object, :prev, id)
    get name_descriptions_show_prev_path(id: description.id)
    q = @controller.query_params(QueryRecord.last)
    assert_redirected_to(
      name_description_path(id: params[:id], params: q)
    )
  end

  def test_index_by_author
    get name_descriptions_index_by_author_path(id: rolf.id)
    assert_template(:index)
  end

  def test_index_by_editor
    get name_descriptions_index_by_editor_path(id: rolf.id)
    assert_redirected_to(
      name_description_path(id: name_descriptions(:coprinus_comatus_desc).id,
        params: @controller.query_params)
    )
  end

  def test_show
    desc = name_descriptions(:peltigera_desc)
    params = { "id" => desc.id.to_s }
    get name_description_path(params)
    assert_template(
      :show, partial: "_show_description"
    )
  end

  def test_show_past
    login("dick")
    desc = name_descriptions(:peltigera_desc)
    old_versions = desc.versions.length
    desc.update(gen_desc: "something new which refers to _P. aphthosa_")
    desc.reload
    new_versions = desc.versions.length
    assert(new_versions > old_versions)
    get name_descriptions_show_past_path(id: desc.id)
    assert_template(
      :show_past, partial: "_name_description"
    )
  end

  def test_create
    name = names(:peltigera)
    params = { "id" => name.id.to_s }
    requires_login(:new, params)
    assert_form_action(action: :new, id: name.id)
  end

  def test_edit
    desc = name_descriptions(:peltigera_desc)
    params = { "id" => desc.id.to_s }
    requires_login(:edit, params)
    assert_form_action(action: :edit, id: desc.id)
  end

  # ----------------------------
  #  Test project drafts.
  # ----------------------------

  # Ensure that draft owner can see a draft they own
  def test_show_draft
    draft = name_descriptions(:draft_coprinus_comatus)
    login(draft.user.login)
    get name_description_path(id: draft.id)
    assert_template(:show, partial: "_show_description")
  end

  # Ensure that an admin can see a draft they don't own
  def test_show_draft_admin
    draft = name_descriptions(:draft_coprinus_comatus)
    assert_not_equal(draft.user, mary)
    login(mary.login)
    get name_description_path(id: draft.id)
    assert_template(:show, partial: "_show_description")
  end

  # Ensure that an member can see a draft they don't own
  def test_show_draft_member
    draft = name_descriptions(:draft_agaricus_campestris)
    assert_not_equal(draft.user, katrina)
    login(katrina.login)
    get name_description_path(id: draft.id)
    assert_template(:show, partial: "_show_description")
  end

  # Ensure that a non-member cannot see a draft
  def test_show_draft_non_member
    project = projects(:eol_project)
    draft = name_descriptions(:draft_agaricus_campestris)
    assert(draft.belongs_to_project?(project))
    assert_not(project.is_member?(dick))
    login(dick.login)
    get name_description_path(id: draft.id)
    assert_redirected_to(project_path(project.id))
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
                        names(:agaricus_campestris), dick, false)
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
    assert(projects(:eol_project).is_member?(katrina))
    assert_equal("EOL Project",
                 name_descriptions(:draft_agaricus_campestris).source_name)
    edit_draft_tester(name_descriptions(:draft_agaricus_campestris),
                      katrina, false)
  end

  def test_edit_draft_non_member
    assert_not(projects(:eol_project).is_member?(dick))
    assert_equal("EOL Project",
                 name_descriptions(:draft_coprinus_comatus).source_name)
    edit_draft_tester(name_descriptions(:draft_coprinus_comatus),
                      dick, false, false)
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

  def test_make_description_default
    desc = name_descriptions(:peltigera_alt_desc)
    assert_not_equal(desc, desc.parent.description)
    make_description_default_helper(desc)
    desc.parent.reload
    assert_equal(desc, desc.parent.description)
  end

  def test_non_public_description_cannot_be_default
    desc = name_descriptions(:peltigera_user_desc)
    current_default = desc.parent.description
    make_description_default_helper(desc)
    desc.parent.reload
    assert_not_equal(desc, desc.parent.description)
    assert_equal(current_default, desc.parent.description)
  end

  # Owner can publish.
  def test_publish_draft
    publish_draft_helper(name_descriptions(:draft_coprinus_comatus), nil,
                         :merged, false)
  end

  # Admin can, too.
  def test_publish_draft_admin
    publish_draft_helper(name_descriptions(:draft_coprinus_comatus), mary,
                         :merged, false)
  end

  # Other members cannot.
  def test_publish_draft_member
    publish_draft_helper(name_descriptions(:draft_agaricus_campestris), katrina,
                         false, false)
  end

  # Non-members certainly can't.
  def test_publish_draft_non_member
    publish_draft_helper(
      name_descriptions(:draft_agaricus_campestris), dick, false, false
    )
  end

  # Non-members certainly can't.
  def test_publish_draft_conflict
    draft = name_descriptions(:draft_coprinus_comatus)
    # Create a simple public description to cause conflict.
    name = draft.name
    name.description = desc = Name::Description.create!(
      name: name,
      user: rolf,
      source_type: :public,
      source_name: "",
      public: true,
      gen_desc: "Pre-existing general description."
    )
    name.save
    desc.admin_groups << UserGroup.reviewers
    desc.writer_groups << UserGroup.all_users
    desc.reader_groups << UserGroup.all_users
    # It should make the draft both public and default, "true" below tells it
    # that the default gen_desc should look like the draft's after done.  No
    # more conflicts.
    publish_draft_helper(draft.reload, nil, true, false)
  end

  def test_destroy_draft_owner
    destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), rolf)
  end

  def test_destroy_draft_admin
    destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), mary)
  end

  def test_destroy_draft_member
    destroy_draft_helper(
      name_descriptions(:draft_agaricus_campestris), katrina, false
    )
  end

  def test_destroy_draft_non_member
    destroy_draft_helper(
      name_descriptions(:draft_agaricus_campestris), dick, false
    )
  end

  # ------------------------------
  #  Test creating descriptions.
  # ------------------------------

  def test_create_description_load_form_no_desc_yet
    name = names(:conocybe_filaris)
    assert_equal(0, name.descriptions.length)
    params = { id: name.id }

    # Make sure it requires login.
    requires_login(:create_name_description, params)
    desc = assigns(:description)
    assert_equal(:public, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)

    # Test draft creation by project member.
    login("rolf") # member
    project = projects(:eol_project)
    get(:create_name_description, params.merge(project: project.id))
    assert_template(:create_name_description, partial: "_form_name_description")
    desc = assigns(:description)
    assert_equal(:project, desc.source_type)
    assert_equal(project.title, desc.source_name)
    assert_equal(false, desc.public)
    assert_equal(false, desc.public_write)

    # Test draft creation by project non-member.
    login("dick")
    get(:create_name_description, params.merge(project: project.id))
    assert_redirected_to(controller: :projects,
                         action: :show,
                         id: project.id)
    assert_flash_error
  end

  def test_create_description_load_form_already_has_desc
    name = names(:peltigera)
    assert_not_equal(0, name.descriptions.length)
    params = { id: name.id }

    # Make sure it requires login.
    requires_login(:create_name_description, params)
    desc = assigns(:description)
    assert_equal(:public, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)

    # Test draft creation by project member.
    login("katrina") # member
    project = projects(:eol_project)
    get(:create_name_description, params.merge(project: project.id))
    assert_template(:create_name_description, partial: "_form_name_description")
    desc = assigns(:description)
    assert_equal(:project, desc.source_type)
    assert_equal(project.title, desc.source_name)
    assert_equal(false, desc.public)
    assert_equal(false, desc.public_write)

    # Test draft creation by project non-member.
    login("dick")
    get(:create_name_description, params.merge(project: project.id))
    assert_redirected_to(controller: :projects,
                         action: :show,
                         id: project.id)
    assert_flash_error

    # Test clone of private description if not reader.
    other = name_descriptions(:peltigera_user_desc)
    login("katrina") # random user
    get(:create_name_description, params.merge(clone: other.id))
    assert_redirected_to(action: :show, id: name.id)
    assert_flash_error

    # Test clone of private description if can read.
    login("dick") # reader
    get(:create_name_description, params.merge(clone: other.id))
    assert_template(:create_name_description, partial: "_form_name_description")
    desc = assigns(:description)
    assert_equal(:user, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(false, desc.public)
    assert_equal(false, desc.public_write)
  end

  def test_create_name_description_public
    # Minimum args.
    params = {
      description: empty_notes.merge(
        source_type: :public,
        source_name: "",
        public: "1",
        public_write: "1"
      )
    }

    # No desc yet -> make new desc default.
    name = names(:conocybe_filaris)
    assert_equal(0, name.descriptions.length)
    post(:create_name_description, params)
    assert_response(:redirect)
    login("dick")
    params[:id] = name.id
    post(:create_name_description, params)
    assert_flash_success
    desc = Name::Description.last
    assert_redirected_to(action: :show_name_description, id: desc.id)
    name.reload
    assert_objs_equal(desc, name.description)
    assert_obj_list_equal([desc], name.descriptions)
    assert_equal(:public, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)
    assert_obj_list_equal([UserGroup.reviewers], desc.admin_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.writer_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.reader_groups)

    # Already have default, try to make public desc private -> warn and make
    # public but not default.
    name = names(:coprinus_comatus)
    assert(default = name.description)
    assert_not_equal(0, name.descriptions.length)
    params[:id] = name.id
    params[:description][:public]       = "0"
    params[:description][:public_write] = "0"
    params[:description][:source_name]  = "Alternate Description"
    post(:create_name_description, params)
    assert_flash_warning # tried to make it private
    desc = Name::Description.last
    assert_redirected_to(action: :show_name_description, id: desc.id)
    name.reload
    assert_objs_equal(default, name.description)
    assert_true(name.descriptions.include?(desc))
    assert_equal(:public, desc.source_type)
    assert_equal("Alternate Description", desc.source_name.to_s)
    assert_obj_list_equal([UserGroup.reviewers], desc.admin_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.writer_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.reader_groups)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)
  end

  def test_create_name_description_bogus_classification
    name = names(:agaricus_campestris)
    login("dick")

    bad_class = "*Order*: Agaricales\r\nFamily: Agaricaceae"
    good_class  = "Family: Agaricaceae\r\nOrder: Agaricales"
    final_class = "Order: _Agaricales_\r\nFamily: _Agaricaceae_"

    params = {
      id: name.id,
      description: empty_notes.merge(
        source_type: :public,
        source_name: "",
        public: "1",
        public_write: "1"
      )
    }

    params[:description][:classification] = bad_class
    post(:create_name_description, params)
    assert_flash_error
    assert_template(:create_name_description, partial: "_form_name_description")

    params[:description][:classification] = good_class
    post(:create_name_description, params)
    assert_flash_success
    desc = Name::Description.last
    assert_redirected_to(action: :show_name_description, id: desc.id)

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
      id: name.id,
      description: empty_notes.merge(
        source_type: :source,
        source_name: "Mushrooms Demystified",
        public: "0",
        public_write: "0"
      )
    }

    post(:create_name_description, params)
    assert_flash_success
    desc = Name::Description.last
    assert_redirected_to(action: :show_name_description, id: desc.id)

    name.reload
    assert_nil(name.description)
    assert_true(name.descriptions.include?(desc))
    assert_equal(:source, desc.source_type)
    assert_equal("Mushrooms Demystified", desc.source_name)
    assert_false(desc.public)
    assert_false(desc.public_write)
    assert_obj_list_equal([UserGroup.one_user(dick)], desc.admin_groups)
    assert_obj_list_equal([UserGroup.one_user(dick)], desc.writer_groups)
    assert_obj_list_equal([UserGroup.one_user(dick)], desc.reader_groups)
  end



end
