#
#  Views: ("*" - login required, "**" - special permission required)
#     list_projects              Project alphabetically.
#     show_project               Show a single project.
#   * add_project                Create a project.
#   * edit_project               Edit a project.
#   * destroy_project            Destroy project.
#     admin_request              Compose email to the project admins
#     send_admin_request         Send email to the project admins
#  ** change_member_status       Adjust the member status of a particular user (admin only)
#  ** add_members                Consider adding any existing user to a project (admin only)
#  ** add_one_member             Add a particular user as a project member (admin only)
#  ** show_draft                 Show the latest version of a draft (member only)
#  ** create_or_edit_draft       Create a new draft if none exists then edit it (member only)
#  ** edit_draft                 Edit an existing draft (draft owner only)

################################################################################

# TODO:
#   Add comments?
#   Projects should be able to log stuff
#   Are search_params needed for project pages?
#   Version drafts

class ProjectController < ApplicationController
  before_filter :login_required, :except => [
    :list_projects,
    :show_project
  ]

  # Show list of latest projects.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @projects, @project_pages
  def list_projects
    store_location
    session_setup
    @project_pages, @projects = paginate(:projects,
       :order => "title", :per_page => 10)
  end

  # Display project by itself.
  # Linked from: show_observation, list_projects
  # Inputs: params[:id] (project)
  # Outputs: @project
  def show_project
    store_location
    @project = Project.find(params[:id])
    @is_member = @project.is_member?(@user)
    @is_admin = @project.is_admin?(@user)
  end

  # Form to create a project.
  # Linked from: list_projects
  # Inputs:
  #   params[:id] (project id)
  #   params[:project][:title]
  #   params[:project][:summary]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders add_project again.
  #   Outputs: @project
  def add_project
    if verify_user()
      if request.method == :get
        @project = Project.new
      else
        title = params[:project][:title]
        project = Project.find_by_title(title)
        user_group = UserGroup.find_by_name(title)
        admin_name = "#{title}.admin"
        admin_group = UserGroup.find_by_name(admin_name)
        if title.nil? || title == ""
          flash_error("Projects must have a title")
        elsif project
          flash_error("Project named '#{project.title}' already exists")
        elsif user_group
          flash_error("Unable to create project because a user group named '#{title}' already exists")
        elsif admin_group
          flash_error("Unable to create project because a user group named '#{admin_name}' already exists")          
        else
          user_group = UserGroup.new()
          user_group.name = title
          user_group.users << @user
          admin_group = UserGroup.new()
          admin_group.name = admin_name
          admin_group.users << @user
          if user_group.save && admin_group.save
            @project = Project.new(params[:project])
            # @project.created_at = Time.now
            @project.user = @user
            @project.user_group = user_group
            @project.admin_group = admin_group
            if @project.save
              # @project.log("Project added by #{@user.login}: #{@project.title}", true)
              flash_notice "Project was successfully added."
              redirect_to(:action => :show_project, :id => @project.id)
            else
              flash_object_errors(@project)
            end
          else
            flash_object_errors(user_group)
            flash_object_errors(admin_group)
          end
        end
      end
    end
  end

  # Form to edit a project
  # Linked from: show_project
  # Inputs:
  #   params[:id]
  #   params[:project][:title]
  #   params[:project][:summary]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders edit_project again.
  #   Outputs: @project
  def edit_project
    @project = Project.find(params[:id])
    if !check_user_id(@project.user_id)
      render(:action => 'show_project', :id => @project.id)
    elsif request.method == :post
      title = params[:project][:title]
      @title = title
      @summary = params[:project][:summary]
      if title.nil? || title == ""
        flash_error("Projects must have a title")
      else
        title_project = Project.find_by_title(title)
        if title_project and (title_project != @project)
          flash_error("The project ''#{title}' already exists.  Please choose a different title.")
        elsif !@project.update_attributes(params[:project]) || !@project.save
          flash_object_errors(@project)
        else
          # @project.log("Project updated by #{@user.login}: #{@project.summary}", false)
          flash_notice "Project was successfully updated."
          redirect_to(:action => 'show_project', :id => @project.id)
        end
      end
    end
  end

  # Callback to destroy a project.
  # Linked from: show_project, show_observation
  # Redirects to show_observation.
  # Inputs: params[:id]
  # Outputs: none
  def destroy_project
    @project = Project.find(params[:id])
    if !check_user_id(@project.user_id)
      render(:action => 'show_project')
    else
      title = @project.title
      user_group = @project.user_group
      admin_group = @project.admin_group
      if @project.destroy
        # project.log("Project destroyed by #{@user.login}: #{title}", false)
        user_group.destroy
        admin_group.destroy
        flash_notice "Project destroyed."
      else
        flash_error "Failed to destroy project."
      end
      redirect_to(:action => :list_projects)
    end
  end
  
  # Form to compose email for the admins
  # Linked from: show_project
  # Inputs:
  #   params[:id]
  # Outputs: @project
  def admin_request
    @project = Project.find(params[:id])
  end

  # Sends email to admins
  # Linked from: admin_request
  # Inputs:
  #   params[:id]
  #   params[:email][:subject]
  #   params[:email][:content]
  # Success:
  #   Redirects to show_project.
  #
  # TODO: Use queued_email mechanism
  def send_admin_request
    sender = @user
    project = Project.find(params[:id])
    subject = params[:email][:subject]
    content = params[:email][:content]
    AccountMailer.deliver_admin_request(sender, project, subject, content)
    flash_notice "Delivered email."
    redirect_to(:action => 'show_project', :id => project.id)
  end
  
  # TODO: Changes should get logged
  def set_status(user, group, add)
    if add
      group.users << user unless group.users.member?(user)
    else
      group.users.delete(user)
    end
    group.save
  end
  
  # Form to adjust permissions for a user with respect to a project
  # Linked from: show_project, add_users, admin_request email
  # Inputs:
  #   params[:id]
  #   params[:candidate]
  #   params[:commit]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders show_project.
  #   Outputs: @project, @candidate
  def change_member_status
    @project = Project.find(params[:id])
    if verify_user() and @project.is_admin?(@user)
      @candidate = User.find(params[:candidate])
      user_group = @project.user_group
      admin_group = @project.admin_group
      if request.method == :post
        admin = member = false
        case params[:commit]
        when :change_member_status_make_admin.l
          admin = member = true
        when :change_member_status_make_member.l
          member = true
        end
        set_status(@candidate, admin_group, admin)
        set_status(@candidate, user_group, member)
        redirect_to(:action => 'show_project', :id => @project.id)
      end
    else
      flash_error("Only the admins for a project can change member permissions.")
      redirect_to(:action => 'show_project', :id => @project.id)
    end
  end
  
  # Action for adding just one member
  # Linked from: add_members
  # Inputs:
  #   params[:id]
  #   params[:candidate]
  # Success or failure:
  #   Redirects to add_members.
  def add_one_member
    @project = Project.find(params[:id])
    if verify_user() and @project.is_admin?(@user)
      @candidate = User.find(params[:candidate])
      set_status(@candidate, @project.user_group, true)
    else
      flash_error("Permission denied.  Only admins for a project can add new members.")
    end
    redirect_to(:action => 'add_members', :id => @project.id)
  end
  
  # View that lists all users with links to add each as a member
  # Linked from: show_project (for admins only)
  # Inputs:
  #   params[:id]
  # Outputs:
  #   @project, @users
  def add_members
    @project = Project.find(params[:id])
    @users = User.find(:all, :order => "login, name")
  end

  # Show the given draft if the current user has permission
  # otherwise just show the project.
  # Linked from: show_project, show_name
  # Inputs:
  #   params[:id]
  # Outputs:
  #   @draft_name
  # Success:
  #   Renders show_draft.
  # Failure: (not member of project)
  #   Redirect to show_project or list_projects (if can't figure out project)
  #   Outputs: @draft_name
  def show_draft
    @draft_name = DraftName.find(params[:id])
    if @draft_name
      project = @draft_name.project
      unless verify_user() and project.is_member?(@user)
        flash_error("Permission denied.  Only project members can view drafts in progress.")
        redirect_to(:action => 'show_project', :id => project.id)
      end
    else
      redirect_to(:action => 'list_projects')
    end
  end
  
  # Look for any drafts of the given name.
  # If none exists create one and start editing.
  # If one exists and it is assocated with this project and user, then start editing.
  # Otherwise report error and show a violating draft.
  # (Really should give warning and provide option for creating a new draft for this project and user,
  # but we'll worry about that later.)
  # Linked from: show_name
  # Inputs:
  #   params[:project]
  #   params[:name]
  # Success:
  #   Redirects to edit_draft.
  # Failure:
  #   Redirects show_draft or show_project or list_projects depending on permissions and validity of input.
  def create_or_edit_draft
    project = Project.find(params[:project])
    name = Name.find(params[:name])
    if project and name
      draft = DraftName.find(:first, :conditions => ["name_id = ? and project_id = ? and user_id = ?", name.id, project.id, @user.id])
      if draft
        redirect_to(:action => 'edit_draft', :id => draft.id)
      else
        draft = DraftName.find(:first, :conditions => ["name_id = ?", name.id])
        if draft
          if draft.project_id == project.id and project.is_admin?(@user)
            redirect_to(:action => 'edit_draft', :id => draft.id)
          else
            flash_error("Permission denied. A draft already exists for the name, #{name.text_name}, in the project, #{project.title}, and multiple drafts for the same name are not yet supported.")
            redirect_to(:action => 'show_draft', :id => draft.id)
          end
        else
          if project.is_member?(@user)
            draft = DraftName.new({
              :user_id => @user.id,
              :project_id => project.id,
              :name_id => name.id})
            for f in Name.all_note_fields:
              draft.send("#{f}=", name.send(f))
            end
            if draft.save
              redirect_to(:action => 'edit_draft', :id => draft.id)
            else
              flash_error("Unable to create new draft")
              redirect_to(:action => 'show_project', :project => project.id)
            end
          else
            flash_error("You do not have permission to create a draft for the project #{project.title}")
            redirect_to(:action => 'show_project', :id => project.id)
          end
        end
      end
    else
      flash_error("Bad arguments: project => #{params[:project]}, name => #{params[:name]} for create_or_edit_draft")
      redirect_to(:action => 'list_projects')
    end
  end

  # Form to edit a draft name
  # Linked from: create_or_edit_draft
  # Inputs:
  #   params[:id]
  #   params[:draft_name][<note-fields>]
  # Success:
  #   Redirects to show_draft.
  # Failure:
  #   Renders edit_draft again.
  #   Outputs: @draft_name
  def edit_draft
    @draft_name = DraftName.find(params[:id])
    if check_user_id(@draft_name.user_id) or @draft_name.project.is_admin?(@user)
      if request.method == :post
        if !@draft_name.update_attributes(params[:draft_name]) || !@draft_name.save
          flash_object_errors(@draft_name)
        else
          flash_notice "Draft was successfully updated."
          redirect_to(:action => 'show_draft', :id => @draft_name.id)
        end
      end
    else
      flash_error("Permission denied: Only the creator of a draft can edit it.")
      redirect_to(:action => 'show_draft', :id => @draft_name.id)
    end
  end
end
