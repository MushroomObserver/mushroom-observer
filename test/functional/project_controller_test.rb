require 'test_helper'

class ProjectControllerTest < ActionController::TestCase
  fixtures :projects
  fixtures :users
  fixtures :user_groups
  fixtures :user_groups_users
  fixtures :draft_names
  fixtures :names

  def test_show_project
    get_with_dump(:show_project, :id => 1)
    assert_response(:success)
    assert_template('show_project')
  end

  def test_list_projects
    get_with_dump(:list_projects)
    assert_response(:success)
    assert_template('list_projects')
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
    post_requires_login(:add_project, params, false)
    assert_redirected_to(:controller => "project", :action => "show_project")
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

  def test_add_project_existing
    title = @eol_project.title
    summary = "The Entoloma On Line Project"
    project = Project.find_by_title(title)
    assert(project)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params, false)
    assert_form_action(:action => 'add_project') # Failure
  end

  def test_add_project_empty_name
    title = ''
    summary = "The Empty Project"
    project = Project.find_by_title(title)
    assert_nil(project)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params, false)
    assert_form_action(:action => 'add_project') # Failure
  end

  def test_add_project_existing_user_group
    title = 'reviewers'
    summary = "Journal Reviewers"
    project = Project.find_by_title(title)
    assert_nil(project)
    params = {
      :project => {
        :title => title,
        :summary => summary
      }
    }
    post_requires_login(:add_project, params, false)
    assert_form_action(:action => 'add_project') # Failure
  end
  
  def test_edit_project
    project = @eol_project
    params = { "id" => project.id.to_s }
    requires_user(:edit_project, "show_project", params, false)
    assert_form_action :action => 'edit_project'
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
    post_requires_user(:edit_project, "show_project", params, false)
    assert_redirected_to(:controller => "project", :action => "show_project")
    project = Project.find_by_title(title)
    assert(project)
    assert_equal(summary, project.summary)
  end

  def test_edit_project_empty_name  
    project = @eol_project
    params = {
      :id => project.id,
      :project => {
        :title => '',
        :summary => project.summary
      }
    }
    post_requires_user(:edit_project, "show_project", params, false)
    assert_form_action(:action => 'edit_project') # Failure
  end
  
  def test_edit_project_existing
    project = @eol_project
    params = {
      :id => project.id,
      :project => {
        :title => @bolete_project.title,
        :summary => project.summary
      }
    }
    post_requires_user(:edit_project, "show_project", params, false)
    assert_form_action(:action => 'edit_project') # Failure
  end

  def test_destroy_project
    project = @bolete_project
    assert(project)
    user_group = project.user_group
    assert(user_group)
    admin_group = project.admin_group
    assert(admin_group)
    params = {"id"=>project.id.to_s}
    requires_user(:destroy_project, "show_project", params, false)
    assert_redirected_to(:action => "list_projects")
    assert_raises(ActiveRecord::RecordNotFound) do
      user_group = UserGroup.find(user_group.id) # Need to reload user group to pick up changes
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      admin_group = UserGroup.find(admin_group.id) # Need to reload user group to pick up changes
    end
  end

  def test_send_admin_request
    params = {
      :id => @eol_project.id,
      :email => {
        :subject => "Admin request subject",
        :message => "Message for admins"
      }
    }
    requires_login :send_admin_request, params, false
    assert_equal("Delivered email.", flash[:notice])
    assert_redirected_to(:action => "show_project", :id => @eol_project.id)
  end

  def test_admin_request
    id = @eol_project.id
    requires_login(:admin_request, {:id => id})
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

  def change_member_status_helper(changer, target_user, commit, admin_before, user_before, admin_after, user_after)
    project = @eol_project
    assert_equal(admin_before, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(user_before, target_user.in_group(@eol_project.user_group.name))
    params = {
      :id => project.id,
      :candidate => target_user.id,
      :commit => commit.l
    }
    post_requires_login(:change_member_status, params, false, changer.login)
    assert_redirected_to(:action => 'show_project', :id => project.id)
    target_user = User.find(target_user.id)
    assert_equal(admin_after, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(user_after, target_user.in_group(@eol_project.user_group.name))    
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
    post_requires_login(:add_one_member, params, false, @mary.login)
    assert_redirected_to(:action => 'add_members', :id => project.id)
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
    post_requires_login(:add_one_member, params, false, @katrina.login)
    assert_redirected_to(:action => 'add_members', :id => project.id)
    target_user = User.find(target_user.id)
    assert_equal(false, target_user.in_group(@eol_project.admin_group.name))
    assert_equal(false, target_user.in_group(@eol_project.user_group.name))    
  end

  def test_add_members
    requires_login(:add_members, { :id => 1})
  end

  # Ensure that draft owner can see a draft they own
  def test_show_draft
    draft = @draft_coprinus_comatus
    requires_login(:show_draft, { :id => draft.id}, :user => draft.user.login)
  end

  # Ensure that an admin can see a draft they don't own
  def test_show_draft_admin
    draft = @draft_coprinus_comatus
    assert_not_equal(draft.user, @mary)
    requires_login(:show_draft, { :id => draft.id}, :user => @mary.login)
  end

  # Ensure that an member can see a draft they don't own
  def test_show_draft_member
    draft = @draft_agaricus_campestris
    assert_not_equal(draft.user, @katrina)
    requires_login(:show_draft, { :id => draft.id}, :user => @katrina.login)
  end

  # Ensure that a non-member cannot see a draft
  def test_show_draft_non_member
    draft = @draft_agaricus_campestris
    assert(!draft.project.is_member?(@dick))
    requires_login(:show_draft, { :id => draft.id}, false, @dick.login)
    assert_redirected_to(:controller => "project", :action => "show_project")
  end

  def test_create_or_edit_draft_owner
    draft = @draft_coprinus_comatus
    count = DraftName.find(:all).size
    params = {
      :project => @eol_project.id,
      :name => @coprinus_comatus.id
    }
    requires_login(:create_or_edit_draft, params, false, draft.user.login)
    assert_redirected_to(:controller => "project", :action => "edit_draft", :id => draft.id)
    assert_equal(count, DraftName.find(:all).size)
  end

  def test_create_or_edit_draft_admin
    draft = @draft_coprinus_comatus
    assert_not_equal(draft.user, @mary)
    count = DraftName.find(:all).size
    params = {
      :project => @eol_project.id,
      :name => @coprinus_comatus.id
    }
    requires_login(:create_or_edit_draft, params, false, @mary.login)
    assert_redirected_to(:controller => "project", :action => "edit_draft", :id => draft.id)
    assert_equal(count, DraftName.find(:all).size)
  end

  def test_create_or_edit_draft_not_owner
    draft = @draft_agaricus_campestris
    assert_not_equal(draft.user, @katrina)
    count = DraftName.find(:all).size
    params = {
      :project => @eol_project.id,
      :name => @agaricus_campestris.id
    }
    requires_login(:create_or_edit_draft, params, false, @katrina.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
    assert_equal(count, DraftName.find(:all).size)
  end

  def test_create_or_edit_draft_not_project
    draft = @draft_boletus_edulis
    assert_not_equal(draft.user, @katrina)
    count = DraftName.find(:all).size
    params = {
      :project => @eol_project.id,
      :name => @boletus_edulis.id
    }
    requires_login(:create_or_edit_draft, params, false, @katrina.login)
    # Technically this ends up redirecting to show_project by way of show_draft
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
    assert_equal(count, DraftName.find(:all).size)
  end

  def test_create_or_edit_draft_new_draft
    count = DraftName.find(:all).size
    params = {
      :project => @eol_project.id,
      :name => @conocybe_filaris.id
    }
    requires_login(:create_or_edit_draft, params, false, @katrina.login)
    assert_redirected_to(:controller => "project", :action => "edit_draft")
    assert_equal(count + 1, DraftName.find(:all).size)
  end

  def test_create_or_edit_draft_no_draft_not_member
    count = DraftName.find(:all).size
    params = {
      :project => @eol_project.id,
      :name => @conocybe_filaris.id
    }
    requires_login(:create_or_edit_draft, params, false, @dick.login)
    assert_redirected_to(:controller => "project", :action => "show_project", :id => @eol_project.id)
    assert_equal(count, DraftName.find(:all).size)
  end

  def test_edit_draft
    draft = @draft_coprinus_comatus
    assert_equal(@katrina, draft.user)
    requires_login(:edit_draft, { :id => draft.id}, true, @katrina.login)
  end

  def test_edit_draft_admin
    draft = @draft_coprinus_comatus
    assert_not_equal(@mary, draft.user)
    requires_login(:edit_draft, { :id => draft.id}, true, @mary.login)
  end

  def test_edit_draft_member
    draft = @draft_agaricus_campestris
    assert_not_equal(@katrina, draft.user)
    requires_login(:edit_draft, { :id => draft.id}, false, @katrina.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
  end

  def test_edit_draft_non_member
    draft = @draft_agaricus_campestris
    assert_not_equal(@dick, draft.user)
    requires_login(:edit_draft, { :id => draft.id}, false, @dick.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
  end

  def test_edit_draft_post
    draft = @draft_coprinus_comatus
    assert_equal(@katrina, draft.user)
    assert_nil(draft.gen_desc)
    gen_desc = "This is a very general description."
    params = {
      :id => draft.id,
      :draft_name => {
        :gen_desc => gen_desc
      }
    }
    post_requires_login(:edit_draft, params, false, @katrina.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
    draft = DraftName.find(draft.id) # Reload
    assert_equal(gen_desc, draft.gen_desc)
  end

  def test_edit_draft_post_admin
    draft = @draft_coprinus_comatus
    assert_not_equal(@mary, draft.user)
    assert_nil(draft.gen_desc)
    gen_desc = "This is a very general description."
    params = {
      :id => draft.id,
      :draft_name => {
        :gen_desc => gen_desc
      }
    }
    post_requires_login(:edit_draft, params, false, @mary.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
    draft = DraftName.find(draft.id) # Reload
    assert_equal(gen_desc, draft.gen_desc)
  end

  def test_edit_draft_post_member
    draft = @draft_agaricus_campestris
    assert_not_equal(@katrina, draft.user)
    assert_nil(draft.gen_desc)
    gen_desc = "This is a very general description."
    params = {
      :id => draft.id,
      :draft_name => {
        :gen_desc => gen_desc
      }
    }
    post_requires_login(:edit_draft, params, false, @katrina.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
    draft = DraftName.find(draft.id) # Reload
    assert_not_equal(gen_desc, draft.gen_desc)
  end

  def test_edit_draft_post_non_member
    draft = @draft_agaricus_campestris
    assert_not_equal(@dick, draft.user)
    assert_nil(draft.gen_desc)
    gen_desc = "This is a very general description."
    params = {
      :id => draft.id,
      :draft_name => {
        :gen_desc => gen_desc
      }
    }
    post_requires_login(:edit_draft, params, false, @dick.login)
    assert_redirected_to(:controller => "project", :action => "show_draft", :id => draft.id)
    draft = DraftName.find(draft.id) # Reload
    assert_not_equal(gen_desc, draft.gen_desc)
  end
end
