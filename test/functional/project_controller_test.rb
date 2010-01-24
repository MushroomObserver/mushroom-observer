require File.dirname(__FILE__) + '/../boot'

class ProjectControllerTest < ControllerTestCase
  fixtures :projects
  fixtures :users
  fixtures :user_groups
  fixtures :user_groups_users
  fixtures :draft_names
  fixtures :names

  def add_project_helper(title, summary)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params)
    assert_form_action(:action => 'add_project') # Failure
  end

  def edit_project_helper(title, project)
    params = {
      :id => project.id,
      :project => {
        :title => title,
        :summary => project.summary
      }
    }
    post_requires_user(:edit_project, :show_project, params)
    assert_form_action(:action => 'edit_project') # Failure
  end

  def destroy_project_helper(project, changer)
    assert(project)
    total_draft_count = DraftName.all.size
    project_draft_count = project.draft_names.size
    assert(project_draft_count > 0)
    params = { :id => project.id.to_s }
    requires_user(:destroy_project, :show_project, params, changer.login)
    assert_response(:action => :show_project)
    assert(Project.find(project.id))
    assert(UserGroup.find(project.user_group.id))
    assert(UserGroup.find(project.admin_group.id))
    assert_equal(total_draft_count, DraftName.all.size)
  end

  def change_member_status_helper(changer, target_user, commit, admin_before, user_before, admin_after, user_after)
    project = @eol_project
    assert_equal(admin_before, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(user_before, target_user.in_group(@eol_project.user_group.name))
    params = {
      :id => project.id,
      :candidate => target_user.id,
      :commit => commit.l
    }
    post_requires_login(:change_member_status, params, changer.login)
    assert_response(:action => 'show_project', :id => project.id)
    target_user = User.find(target_user.id)
    assert_equal(admin_after, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(user_after, target_user.in_group(@eol_project.user_group.name))
  end

  def create_or_edit_draft_tester(draft, project, name, user=nil, page=nil)
    if user
      assert_not_equal(draft.user, user)
    else
      user = draft.user
    end
    count = DraftName.all.size
    params = {
      :project => project.id,
      :name => name.id
    }
    requires_login(:create_or_edit_draft, params, user.login)
    if page
      assert_response(:action => page, :id => draft.id)
    else
      assert_response('edit_draft')
    end
    assert_equal(count, DraftName.all.size)
  end

  def edit_draft_tester(draft, user=nil, success=true)
    if user
      assert_not_equal(user, draft.user)
    else
      user = draft.user
    end
    requires_login(:edit_draft, { :id => draft.id }, user.login)
    if success
      assert_response('edit_draft')
    else
      assert_response(:action => "show_draft", :id => draft.id)
    end
  end

  def edit_draft_post_helper(draft, user=nil, success=true, classification="")
    if user
      assert_not_equal(user, draft.user)
    else
      user = draft.user
    end
    gen_desc = "This is a very general description."
    assert_not_equal(gen_desc, draft.gen_desc)
    diag_desc = "This is a diagnostic description"
    assert_not_equal(diag_desc, draft.diag_desc)
    params = {
      :id => draft.id,
      :draft_name => {
        :gen_desc => gen_desc,
        :diag_desc => diag_desc,
        :classification => classification
      }
    }
    post_requires_login(:edit_draft, params, user.login)
    if success or classification == ""
      assert_response(:action => "show_draft", :id => draft.id)
    else
      assert_response('edit_draft')
    end
    draft.reload
    if success
      assert_equal(gen_desc, draft.gen_desc)
      assert_equal(diag_desc, draft.diag_desc)
      assert_equal(classification, draft.classification)
    else
      assert_not_equal(gen_desc, draft.gen_desc)
      assert_not_equal(diag_desc, draft.diag_desc)
      assert_not_equal(classification, draft.classification)
    end
  end

  def publish_draft_helper(draft, user=nil, success=true, action='show_draft')
    if user
      assert_not_equal(draft.user, user)
    else
      user = draft.user
    end
    draft_gen_desc = draft.gen_desc
    name_gen_desc = draft.name.gen_desc
    same_gen_desc = (draft_gen_desc == draft.name.gen_desc)
    name_id = draft.name_id
    params = {
      :id => draft.id
    }
    requires_login(:publish_draft, params, user.login)
    name = Name.find(name_id)
    if success
      assert_response(:controller => 'name', :action => 'show_name', :id => name_id)
      assert_equal(draft_gen_desc, name.gen_desc)
    else
      assert_response(:action => action, :id => draft.id)
      assert_equal(same_gen_desc, draft_gen_desc == draft.name.gen_desc)
    end
  end

  def destroy_draft_helper(draft, user=nil, success=true)
    if user
      assert_not_equal(draft.user, user)
    else
      user = draft.user
    end
    assert(draft)
    total_draft_count = DraftName.all.size
    params = {
      :id => draft.id
    }
    requires_login(:destroy_draft, params, user.login)
    assert_response('show_project')
    if success
      assert_raises(ActiveRecord::RecordNotFound) do
        draft = DraftName.find(draft.id)
      end
      assert_equal(total_draft_count - 1, DraftName.all.size)
    else
      assert(DraftName.find(draft.id))
      assert_equal(total_draft_count, DraftName.all.size)
    end
  end

################################################################################

  def test_add_project_existing
    add_project_helper(@eol_project.title, "The Entoloma On Line Project")
  end

  def test_show_project
    get_with_dump(:show_project, :id => 1)
    assert_response('show_project')
  end

  def test_list_projects
    get_with_dump(:list_projects)
    assert_response('list_projects')
  end

  def test_add_project
    requires_login(:add_project)
    assert_form_action(:action => 'add_project')
  end

  def test_add_project_post
    title = "Amanita Research"
    summary = "The Amanita Research Project"
    project = Project.find_by_title(title)
    assert_nil(project)
    user_group = UserGroup.find_by_name(title)
    assert_nil(user_group)
    admin_group = UserGroup.find_by_name("#{title}.admin")
    assert_nil(admin_group)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params)
    assert_response(:action => :show_project)
    project = Project.find_by_title(title)
    assert(project)
    assert_equal(title, project.title)
    assert_equal(summary, project.summary)
    assert_equal(@rolf, project.user)
    user_group = UserGroup.find_by_name(title)
    assert(user_group)
    assert_equal([@rolf], user_group.users)
    admin_group = UserGroup.find_by_name("#{title}.admin")
    assert(admin_group)
    assert_equal([@rolf], admin_group.users)
  end

  def test_add_project_empty_name
    add_project_helper('', "The Empty Project")
  end

  def test_add_project_existing_user_group
    add_project_helper('reviewers', "Journal Reviewers")
  end

  def test_edit_project
    project = @eol_project
    params = { "id" => project.id.to_s }
    requires_user(:edit_project, :show_project, params)
    assert_form_action(:action => 'edit_project')
  end

  def test_edit_project_post
    title = "EOL Project"
    summary = "This has become the Entoloma On Line project"
    project = Project.find_by_title(title)
    assert(project)
    assert_not_equal(summary, project.summary)
    params = {
      :id => project.id,
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_user(:edit_project, :show_project, params)
    assert_response(:action => :show_project)
    project = Project.find_by_title(title)
    assert(project)
    assert_equal(summary, project.summary)
  end

  def test_edit_project_empty_name
    edit_project_helper('', @eol_project)
  end

  def test_edit_project_existing
    edit_project_helper(@bolete_project.title, @eol_project)
  end

  def test_destroy_project
    project = @bolete_project
    assert(project)
    user_group = project.user_group
    assert(user_group)
    admin_group = project.admin_group
    assert(admin_group)
    total_draft_count = DraftName.all.size
    project_draft_count = project.draft_names.size
    assert(project_draft_count > 0)
    params = { :id => project.id.to_s }
    requires_user(:destroy_project, :show_project, params, 'dick')
    assert_response(:action => :list_projects)
    assert_raises(ActiveRecord::RecordNotFound) do
      project = Project.find(project.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      user_group = UserGroup.find(user_group.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      admin_group = UserGroup.find(admin_group.id)
    end
    assert_equal(total_draft_count - project_draft_count, DraftName.all.size)
  end

  def test_destroy_project_other
    destroy_project_helper(@bolete_project, @rolf)
  end

  def test_destroy_project_member
    assert(@eol_project.is_member?(@katrina))
    destroy_project_helper(@eol_project, @katrina)
  end

  def test_send_admin_request
    params = {
      :id => @eol_project.id,
      :email => {
        :subject => "Admin request subject",
        :message => "Message for admins"
      }
    }
    requires_login(:send_admin_request, params)
    assert_response(:action => "show_project", :id => @eol_project.id)
    assert_flash(:admin_request_success.t(:title => @eol_project.title))
  end

  def test_admin_request
    id = @eol_project.id
    requires_login(:admin_request, :id => id)
    assert_form_action(:action => 'send_admin_request', :id => id)
  end

  def test_change_member_status
    project = @eol_project
    params = {
      :id => project.id,
      :candidate => @mary.id
    }
    requires_login(:change_member_status, params)
    assert_form_action(:action => 'change_member_status', :candidate => @mary.id)
  end

  # non-admin member -> non-admin member (should be a no-op)
  def test_change_member_status_member_make_member
    change_member_status_helper(@rolf, @katrina, :change_member_status_make_member, false, true, false, true)
  end

  # non-admin member -> admin member
  def test_change_member_status_member_make_admin
    change_member_status_helper(@mary, @katrina, :change_member_status_make_admin, false, true, true, true)
  end

  # non-admin member -> non-member
  def test_change_member_status_member_remove_member
    change_member_status_helper(@rolf, @katrina, :change_member_status_remove_member, false, true, false, false)
  end

  # admin member -> non-admin member
  def test_change_member_status_admin_make_member
    change_member_status_helper(@mary, @mary, :change_member_status_make_member, true, true, false, true)
  end

  # admin member -> admin member (should be a no-op)
  def test_change_member_status_admin_make_admin
    change_member_status_helper(@rolf, @mary, :change_member_status_make_admin, true, true, true, true)
  end

  # admin member -> non-member
  def test_change_member_status_admin_remove_member
    change_member_status_helper(@mary, @mary, :change_member_status_remove_member, true, true, false, false)
  end

  # non-member -> non-admin member
  def test_change_member_status_non_member_make_member
    change_member_status_helper(@rolf, @dick, :change_member_status_make_member, false, false, false, true)
  end

  # non-member -> admin member
  def test_change_member_status_non_member_make_admin
    change_member_status_helper(@mary, @dick, :change_member_status_make_admin, false, false, true, true)
  end

  # non-member -> non-member (should be a no-op)
  def test_change_member_status_non_member_remove_member
    change_member_status_helper(@rolf, @dick, :change_member_status_remove_member, false, false, false, false)
  end

  # The following should all be no-ops
  def test_change_member_status_by_member_make_member
    change_member_status_helper(@katrina, @dick, :change_member_status_make_member, false, false, false, false)
  end

  def test_change_member_status_by_non_member_make_admin
    change_member_status_helper(@dick, @katrina, :change_member_status_make_admin, false, true, false, true)
  end

  def test_change_member_status_by_member_remove_member
    change_member_status_helper(@katrina, @katrina, :change_member_status_remove_member, false, true, false, true)
  end

  # There are many other combinations that shouldn't work for change_member_status, but I think the above
  # covers the key cases


  def test_add_one_member_admin
    project = @eol_project
    target_user = @dick
    assert_equal(false, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(false, target_user.in_group(@eol_project.user_group.name))
    params = {
      :id => project.id,
      :candidate => target_user.id
    }
    post_requires_login(:add_one_member, params, @mary.login)
    assert_response(:action => 'add_members', :id => project.id)
    target_user = User.find(target_user.id)
    assert_equal(false, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(true, target_user.in_group(@eol_project.user_group.name))
  end

  def test_add_one_member_member
    project = @eol_project
    target_user = @dick
    assert_equal(false, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(false, target_user.in_group(@eol_project.user_group.name))
    params = {
      :id => project.id,
      :candidate => target_user.id
    }
    post_requires_login(:add_one_member, params, @katrina.login)
    assert_response(:action => 'add_members', :id => project.id)
    target_user = User.find(target_user.id)
    assert_equal(false, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(false, target_user.in_group(@eol_project.user_group.name))
  end

  def test_add_members
    requires_login(:add_members, :id => @eol_project.id)
  end

  def test_add_members_non_admin
    project_id = @eol_project.id
    requires_login(:add_members, { :id => project_id }, @katrina.login)
    assert_response(:action => 'show_project', :id => project_id)
  end

  # Ensure that draft owner can see a draft they own
  def test_show_draft
    draft = @draft_coprinus_comatus
    requires_login(:show_draft, { :id => draft.id }, draft.user.login)
    assert_response('show_draft')
  end

  # Ensure that an admin can see a draft they don't own
  def test_show_draft_admin
    draft = @draft_coprinus_comatus
    assert_not_equal(draft.user, @mary)
    requires_login(:show_draft, { :id => draft.id }, @mary.login)
    assert_response('show_draft')
  end

  # Ensure that an member can see a draft they don't own
  def test_show_draft_member
    draft = @draft_agaricus_campestris
    assert_not_equal(draft.user, @katrina)
    requires_login(:show_draft, { :id => draft.id }, @katrina.login)
    assert_response('show_draft')
  end

  # Ensure that a non-member cannot see a draft
  def test_show_draft_non_member
    draft = @draft_agaricus_campestris
    assert(!draft.project.is_member?(@dick))
    requires_login(:show_draft, { :id => draft.id }, @dick.login)
    assert_response(:action => "show_project")
  end

  def test_create_or_edit_draft_owner
    create_or_edit_draft_tester(@draft_coprinus_comatus, @eol_project, @coprinus_comatus)
  end

  def test_create_or_edit_draft_admin
    create_or_edit_draft_tester(@draft_coprinus_comatus, @eol_project, @coprinus_comatus, @mary)
  end

  def test_create_or_edit_draft_not_owner
    create_or_edit_draft_tester(@draft_agaricus_campestris, @eol_project, @agaricus_campestris, @katrina, "show_draft")
  end

  def test_create_or_edit_draft_not_project
    create_or_edit_draft_tester(@draft_boletus_edulis, @eol_project, @boletus_edulis, @katrina, "show_draft")
  end

  def test_create_or_edit_draft_new_draft
    count = DraftName.all.size
    params = {
      :project => @eol_project.id,
      :name => @conocybe_filaris.id
    }
    requires_login(:create_or_edit_draft, params, @katrina.login)
    assert_response('edit_draft')
    assert_equal(count + 1, DraftName.all.size)
  end

  def test_create_or_edit_draft_no_draft_not_member
    count = DraftName.all.size
    params = {
      :project => @eol_project.id,
      :name => @conocybe_filaris.id
    }
    requires_login(:create_or_edit_draft, params, @dick.login)
    assert_response(:action => "show_project", :id => @eol_project.id)
    assert_equal(count, DraftName.all.size)
  end

  def test_edit_draft
    edit_draft_tester(@draft_coprinus_comatus)
  end

  def test_edit_draft_admin
    assert(@draft_coprinus_comatus.project.is_admin?(@mary))
    edit_draft_tester(@draft_coprinus_comatus, @mary)
  end

  def test_edit_draft_member
    assert(@draft_coprinus_comatus.project.is_member?(@katrina))
    edit_draft_tester(@draft_agaricus_campestris, @katrina, false)
  end

  def test_edit_draft_non_member
    assert(!@draft_agaricus_campestris.project.is_member?(@dick))
    edit_draft_tester(@draft_agaricus_campestris, @dick, false)
  end

  def test_edit_draft_post
    edit_draft_post_helper(@draft_coprinus_comatus)
  end

  def test_edit_draft_post_admin
    edit_draft_post_helper(@draft_coprinus_comatus, @mary)
  end

  def test_edit_draft_post_member
    edit_draft_post_helper(@draft_agaricus_campestris, @katrina, false)
  end

  def test_edit_draft_post_non_member
    edit_draft_post_helper(@draft_agaricus_campestris, @dick, false)
  end

  def test_edit_draft_post_bad_classification
    edit_draft_post_helper(@draft_coprinus_comatus, nil, false, "**Domain**: Eukarya")
  end

  def test_publish_draft
    publish_draft_helper(@draft_coprinus_comatus)
  end

  def test_publish_draft_admin
    publish_draft_helper(@draft_coprinus_comatus, @mary)
  end

  def test_publish_draft_member
    publish_draft_helper(@draft_agaricus_campestris, @katrina, false)
  end

  def test_publish_draft_non_member
    publish_draft_helper(@draft_agaricus_campestris, @dick, false)
  end

  def test_publish_draft_bad_classification
    publish_draft_helper(@draft_lactarius_alpinus, nil, false, 'edit_draft')
  end

  def test_destroy_draft
    destroy_draft_helper(@draft_coprinus_comatus)
  end

  def test_destroy_draft_admin
    destroy_draft_helper(@draft_coprinus_comatus, @mary)
  end

  def test_destroy_draft_member
    destroy_draft_helper(@draft_agaricus_campestris, @katrina, false)
  end

  def test_destroy_draft_non_member
    destroy_draft_helper(@draft_agaricus_campestris, @dick, false)
  end
end
