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
#  ** edit_draft                 Edit an existing draft (draft owner or admin only)
#  ** publish_draft              Move draft data to a new version of the given naem (draft owner  or admin only)
#  ** destroy_draft              Destroy draft (draft owner or admin only)
#
#  TODO:
#   Add comments?
#   Projects should be able to log stuff
#   Are query_params needed for project pages?
#
################################################################################

class ProjectController < ApplicationController
  require 'set'

  before_filter :login_required, :except => [
    :list_projects,
    :show_project,
  ]

  before_filter :disable_link_prefetching, :except => [
    :admin_request,
    :change_member_status,
    :create_or_edit_draft,
    :edit_draft,
    :edit_project,
    :show_draft,
    :show_project,
  ]

  # Show list of latest projects.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @projects, @project_pages
  def list_projects
    store_location
    store_query
    query = find_or_create_query(:Project, :all, :by => :title)
    @pages = paginate_numbers(:page, 10)
    @objects = query.paginate(@pages)
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

    @name_count = Project.connection.select_value %(
      SELECT count(*) AS c FROM (
        SELECT DISTINCT names.id
        FROM names, users, user_groups_users, authors_names
        WHERE review_status IN ('vetted', 'unvetted')
          AND users.id = authors_names.user_id
          AND authors_names.name_id = names.id
          AND user_groups_users.user_group_id = #{@project.user_group_id}
          AND user_groups_users.user_id = users.id
          AND users.id != 1
      ) AS ctable
    )

    @draft_data = Project.connection.select_all %(
      SELECT names.display_name, draft_names.id, draft_names.user_id
      FROM names, draft_names
      WHERE draft_names.name_id = names.id
        AND draft_names.project_id = #{params[:id]}
      ORDER BY names.search_name
    )
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
    if request.method == :get
      @project = Project.new
    else
      title = params[:project][:title].to_s
      project = Project.find_by_title(title)
      user_group = UserGroup.find_by_name(title)
      admin_name = "#{title}.admin"
      admin_group = UserGroup.find_by_name(admin_name)
      if title == ""
        flash_error(:add_project_need_title.t)
      elsif project
        flash_error(:add_project_already_exists.t(:title => project.title))
      elsif user_group
        flash_error(:add_project_group_exists.t(:group => title))
      elsif admin_group
        flash_error(:add_project_group_exists.t(:group => admin_name))
      else
        # Create members group.
        user_group = UserGroup.new
        user_group.name = title
        user_group.users << @user

        # Create admin group.
        admin_group = UserGroup.new
        admin_group.name = admin_name
        admin_group.users << @user

        # Create project.
        @project = Project.new(params[:project])
        # @project.created = Time.now
        @project.user = @user
        @project.user_group = user_group
        @project.admin_group = admin_group

        if !user_group.save
          flash_object_errors(user_group)
        elsif !admin_group.save
          flash_object_errors(admin_group)
        elsif !@project.save
          flash_object_errors(@project)
        else
          Transaction.post_project(
            :id          => @project,
            :title       => @project.title,
            :summary     => @project.summary,
            :admin_group => admin_group,
            :user_group  => user_group
          )
          # @project.log("Project added by #{@user.login}: #{@project.title}")
          flash_notice(:add_project_success.t)
          redirect_to(:action => :show_project, :id => @project.id)
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
    if !check_permission!(@project.user_id)
      redirect_to(:action => 'show_project', :id => @project.id)
    elsif request.method == :post
      @title = params[:project][:title].to_s
      @summary = params[:project][:summary]
      args = {}
      args[:set_title]   = @title   if @project_title   != @title
      args[:set_summary] = @summary if @project_summary != @summary
      if @title == ''
        flash_error(:add_project_need_title.t)
      elsif Project.find_by_title(@title) != @project
        flash_error(:add_project_already_exists.t(:title => @title))
      elsif !@project.update_attributes(params[:project])
        flash_object_errors(@project)
      else
        if !args.empty?
          args[:id] = @project
          Transaction.put_project(args)
        end
        # @project.log("Project updated by #{@user.login}: #{@project.summary}", :touch => false)
        flash_notice(:edit_project_success.t)
        redirect_to(:action => 'show_project', :id => @project.id)
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
    if !check_permission!(@project.user_id)
      redirect_to(:action => 'show_project')
    else
      title = @project.title
      user_group = @project.user_group
      admin_group = @project.admin_group
      for d in @project.draft_names
        d.destroy
        # Transaction.delete_something?(TODO)
      end
      if @project.destroy
        # project.log("Project destroyed by #{@user.login}: #{title}", :touch => false)
        user_group.destroy
        admin_group.destroy
        Transaction.delete_project(:id => @project)
        Transaction.delete_user_group(:id => user_group)
        Transaction.delete_user_group(:id => admin_group)
        flash_notice(:destroy_project_success.t)
      else
        flash_error(:destroy_project_failed.t)
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
    for receiver in project.admin_group.users
      AccountMailer.deliver_admin_request(sender, receiver, project, subject, content)
    end
    flash_notice(:admin_request_success.t(:title => project.title))
    redirect_to(:action => 'show_project', :id => project.id)
  end

  # TODO: Changes should get logged
  def set_status(user, group, add)
    if add
      group.users << user unless group.users.member?(user)
      Transaction.put_user_group(
        :id       => group,
        :add_user => user
      )
    else
      group.users.delete(user)
      Transaction.put_user_group(
        :id       => group,
        :del_user => user
      )
    end
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
    if @project.is_admin?(@user)
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
      flash_error(:change_member_status_denied.t)
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
    if @project.is_admin?(@user)
      @candidate = User.find(params[:candidate])
      set_status(@candidate, @project.user_group, true)
    else
      flash_error(:add_members_denied.t)
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
    if @project.is_admin?(@user)
      @users = User.find(:all, :order => "login, name")
    else
      redirect_to(:action => 'show_project', :id => @project.id)
    end
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
      unless project.is_member?(@user)
        flash_error(:show_draft_denied.t)
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
    alt_page = nil # Meaning go to edit_draft
    if project and name
      draft = DraftName.find(:first, :conditions => ["name_id = ? and project_id = ? and user_id = ?", name.id, project.id, @user.id])
      if draft
        if not draft.can_edit?(@user)
          alt_page = 'show_draft'
        end
      else
        draft = DraftName.find(:first, :conditions => ["name_id = ?", name.id])
        if draft
          unless draft.project_id == project.id and project.is_admin?(@user)
            flash_error(:create_draft_multiple.t(:name => name.display_name, :title => project.title))
            alt_page = 'show_draft'
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
            if draft.has_any_notes?
              draft.license_id = @user.license_id
            else
              draft.license_id = nil
            end
            unless draft.save
              # Transaction.post_something?(TODO)
              flash_error(:create_draft_failed.t)
              draft = nil
            end
          else
            flash_error(:create_draft_create_denied.t(:title => project.title))
            draft = nil
          end
        end
      end
      if draft
        if alt_page
          redirect_to(:action => 'show_draft', :id => draft.id)
        else
          @draft_name = draft
          @licenses = License.current_names_and_ids(draft.license)
          render(:action => 'edit_draft')
        end
      else
        redirect_to(:action => 'show_project', :id => project.id)
      end
    else
      flash_error(:create_draft_bad_args.t(:project => params[:project],
                                           :name => params[:name]))
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
    @licenses = License.current_names_and_ids(@draft_name.license)
    if @draft_name.can_edit?(@user)
      if request.method == :post
        begin
          params[:draft_name][:classification] = Name.validate_classification(@draft_name.name.rank, params[:draft_name][:classification])
          if !@draft_name.update_attributes(params[:draft_name])
            flash_object_errors(@draft_name)
          else
            # Transaction.put_something?(TODO)
            flash_notice(:create_draft_updated.t)
            redirect_to(:action => 'show_draft', :id => @draft_name.id)
          end
        rescue RuntimeError => err
          flash_error(err.to_s) if !err.nil?
          flash_object_errors(@draft_name)
          @draft_name.attributes = params[:draft_name]
        end
      end
    else
      flash_error(:create_draft_edit_denied.t)
      redirect_to(:action => 'show_draft', :id => @draft_name.id)
    end
  end

  # Publishes the draft back to the originating name
  # Linked from: show_draft
  # Inputs:
  #   params[:id]
  # Success:
  #   Redirects to show_name.
  # Failure:
  #   Redirects to show_draft.
  def publish_draft
    draft = DraftName.find(params[:id])
    if check_permission!(draft.user_id) or draft.project.is_admin?(@user)
      begin
        draft.classification = Name.validate_classification(draft.name.rank, draft.classification)
        name = draft.name
        args = { :id => name }
        name.license_id = draft.license_id
        args[:set_license] = draft.license if draft.license
        for f in Name.all_note_fields
          name.send("#{f}=", draft.send(f))
          args["set_#{f}"] = draft.send(f).to_s
        end
        if name.changed? &&
           name.save
          name.log(:log_name_updated)
          Transaction.put_name(args)
        end
        name.update_review_status(:vetted)
        user_set = Set.new(name.authors)
        user_set.merge(UserGroup.find_by_name('reviewers').users)
        for recipient in user_set
          if recipient && recipient.created_here
            QueuedEmail::Publish.create_email(@user, recipient, name)
          end
        end
        redirect_to(:controller => 'name', :action => 'show_name', :id => name.id)
      rescue RuntimeError => err
        flash_error(err.to_s) if !err.nil?
        flash_object_errors(draft)
        redirect_to(:action => 'edit_draft', :id => draft.id)
      end
    else
      flash_error(:publish_draft_denied.t)
      redirect_to(:action => 'show_draft', :id => draft.id)
    end
  end

  # Callback to destroy a draft.
  # Linked from: show_draft
  # Redirects to show_project
  # Inputs: params[:id]
  # Outputs: @project
  def destroy_draft
    draft = DraftName.find(params[:id])
    if check_permission!(draft.user_id) or draft.project.is_admin?(@user)
      if draft.destroy
        # Transaction.delete_something?(TODO)
        flash_notice(:destroy_draft_success.t)
      else
        flash_error(:destroy_draft_failed.t)
      end
    end
    @project = draft.project
    render(:action => 'show_project')
  end
end
