#
#  Views: ("*" - login required)
#     index_comment              List comments in current query.
#     list_comments              List latest comments.
#     show_comments_for_user     Show a comments *for* a user.
#     show_comments_by_user      Show a comments *by* a user.
#     show_comment               Show a single comment.
#     prev_comment               Show a previous comment in index.
#     next_comment               Show a next comment in index.
#   * add_comment                Create a comment.
#   * edit_comment               Edit a comment.
#   * destroy_comment            Destroy comment.
#
################################################################################

class CommentController < ApplicationController
  before_filter :login_required, :except => [
    :index_comment,
    :list_comments,
    :next_comment,
    :prev_comment,
    :show_comment,
    :show_comments_by_user,
    :show_comments_for_user,
  ]

  before_filter :disable_link_prefetching, :except => [
    :add_comment,
    :edit_comment,
    :show_comment,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Show selected list of comments, based on current Query.  (Linked from
  # show_comment, next to "prev" and "next"... or will be.)
  def index_comment
    query = find_or_create_query(:Comment, :all, :by => params[:by] || :created)
    query.params[:by] = params[:by] if params[:by]
    show_selected_comments(query, :id => params[:id])
  end

  # Show list of latest comments. (Linked from left panel.)
  def list_comments
    query = create_query(:Comment, :all, :by => :created)
    show_selected_comments(query)
  end

  # Shows comments for a given user, most recent first.  (Linked from left
  # panel.) 
  def show_comments_for_user
    query = create_query(:Comment, :for_user, :user => params[:id] || @user)
    show_selected_comments(query)
  end

  # Shows comments for a given user, most recent first.  (Linked from left
  # panel.)
  def show_comments_by_user
    query = create_query(:Comment, :by_user, :user => params[:id])
    show_selected_comments(query)
  end

  # Show selected list of comments.
  def show_selected_comments(query, args={})

    # (Eager-loading of names might fail when comments start to apply to
    # objects other than observations.)
    args = { :action => :list_comments, :num_per_page => 24,
             :include => [:user, {:object => :name}] }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['date', :DATE.t], 
      ['user', :user.t],
    ]

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show and Post Comments
  #
  ##############################################################################

  # Display comment by itself.
  # Linked from: show_observation, list_comments
  # Inputs: params[:id] (comment)
  # Outputs: @comment, @object
  def show_comment
    store_location
    pass_query_params
    @comment = Comment.find(params[:id],
                            :include => [:user, {:object => :name}])
    @object = @comment.object
    allowed_to_see!(@object)
  end

  # Go to next comment: redirects to show_comment.
  def next_comment
    redirect_to_next_object(:next, Comment, params[:id])
  end

  # Go to previous comment: redirects to show_comment.
  def prev_comment
    redirect_to_next_object(:prev, Comment, params[:id])
  end

  # Form to create comment for an object.
  # Linked from: show_<object>
  # Inputs:
  #   params[:id] (object id)
  #   params[:type] (object type)
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Success:
  #   Redirects to show_<object>.
  # Failure:
  #   Renders add_comment again.
  #   Outputs: @comment, @object
  def add_comment
    pass_query_params
    @object = Comment.find_object(params[:type], params[:id])
    allowed_to_see!(@object)
    if request.method == :get
      @comment = Comment.new
      @comment.object = @object
    else
      @comment = Comment.new(params[:comment])
      @comment.created  = now = Time.now
      @comment.modified = now
      @comment.user     = @user
      @comment.object   = @object
      if @comment.save
        type = @object.class.to_s.underscore.to_sym
        Transaction.post_comment(
          :id      => @comment,
          type     => @object,
          :summary => @comment.summary,
          :content => @comment.comment
        )
        if @object.respond_to?(:log)
          @object.log(:log_comment_added, :summary => @comment.summary)
        end
        flash_notice :runtime_form_comments_create_success.t(:id => @comment.id)
        params = @comment.object_type == 'Observation' ? query_params : nil
        redirect_to(:controller => @object.show_controller,
          :action => @object.show_action, :id => @object.id,
          :params => params)
      else
        flash_object_errors(@comment)
      end
    end
  end

  # Form to edit a comment for an object..
  # Linked from: show_comment, show_object.
  # Inputs:
  #   params[:id]
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Success:
  #   Redirects to show_object.
  # Failure:
  #   Renders edit_comment again.
  #   Outputs: @comment, @object
  def edit_comment
    pass_query_params
    @comment = Comment.find(params[:id])
    @object = @comment.object
    allowed_to_see!(@object)
    if !check_permission!(@comment.user_id)
      redirect_to(:controller => @object.show_controller,
                  :action => @object.show_action, :id => @object.id,
                  :params => query_params)
    elsif request.method == :post
      @comment.attributes = params[:comment]
      args = {}
      args[:summary] = @comment.summary if @comment.summary_changed?
      args[:content] = @comment.comment if @comment.comment_changed?
      if !@comment.save
        flash_object_errors(@comment)
      else
        if !args.empty?
          args[:id] = @comment
          Transaction.put_comment(args)
        end
        if @object.respond_to?(:log)
          @object.log(:log_comment_updated, :summary => @comment.summary,
                      :touch => false)
        end
        flash_notice(:runtime_form_comments_edit_success.t(:id => @comment.id))
        redirect_to(:controller => @object.show_controller,
                    :action => @object.show_action, :id => @object.id,
                    :params => query_params)
      end
    end
  end

  # Callback to destroy a comment.
  # Linked from: show_comment, show_object.
  # Redirects to show_object.
  # Inputs: params[:id]
  # Outputs: none
  def destroy_comment
    pass_query_params
    @comment = Comment.find(params[:id])
    @object = @comment.object
    if !check_permission!(@comment.user_id)
      redirect_to(:controller => @object.show_controller,
                  :action => @object.show_action, :id => @object.id,
                  :params => query_params)
    else
      if @comment.destroy
        Transaction.delete_comment(:id => @comment)
        flash_notice :runtime_form_comments_destroy_success.t(:id => params[:id])
      else
        flash_error :runtime_form_comments_destroy_failed.t(:id => params[:id])
      end
      redirect_to(:controller => @object.show_controller,
                  :action => @object.show_action, :id => @object.id,
                  :params => query_params)
    end
  end

  # Make sure users can't see/add comments on objects they aren't allowed to
  # view!
  def allowed_to_see!(object)
    if object.respond_to?(:is_reader?) and
       !object.is_reader?(@user)
      flash_error(:runtime_show_description_denied.t)
      parent = object.parent
      redirect_to(:controller => parent.show_controller,
                  :action => parent.show_action, :id => parent.id)
    end
  end
end
