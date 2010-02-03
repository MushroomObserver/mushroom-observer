#
#  Views: ("*" - login required)
#     list_comments              List latest comments.
#     show_comments_for_user     Show a comments *for* a user.
#     show_comments_by_user      Show a comments *by* a user.
#     show_comment               Show a single comment.
#   * add_comment                Create a comment.
#   * edit_comment               Edit a comment.
#   * destroy_comment            Destroy comment.
#
################################################################################

class CommentController < ApplicationController
  before_filter :login_required, :except => [
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
  def list_comments
    query = find_or_create_query(:Comment, :all, :by => :created)
    show_selected_comments(query, :id => params[:id])
  end

  # Show list of latest comments. (Linked from left panel.)
  def all_comments
    query = create_query(:Comment, :all, :by => :created)
    show_selected_comments(query)
  end

  # Shows comments for a given user, most recent first.  (Linked from left
  # panel.) 
  def show_comments_for_user
    query = create_query(:Comment, :for_user, :user => params[:id])
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
    args = { :action => :list_comments, :num_per_page => 24 }.merge(args)
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
    @comment = Comment.find(params[:id])
    @object = @comment.object
  end

  # Go to next comment: redirects to show_comment.
  def next_comment
    comment = Comment.find(params[:id])
    redirect_to_next_object(:next, comment)
  end

  # Go to previous comment: redirects to show_comment.
  def prev_comment
    comment = Comment.find(params[:id])
    redirect_to_next_object(:prev, comment)
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
        flash_notice :form_comments_create_success.t
        params = @comment.object_type == 'Observation' ? query_params : nil
        redirect_to(:controller => @object.show_controller,
          :action => @object.show_action, :id => @object.id,
          :params => params)
      else
        flash_object_errors(@comment)
      end
    end
  end

  # Form to edit a comment for an observation.
  # Linked from: show_comment, show_observation
  # Inputs:
  #   params[:id]
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Success:
  #   Redirects to show_comment.
  # Failure:
  #   Renders edit_comment again.
  #   Outputs: @comment, @object
  def edit_comment
    @comment = Comment.find(params[:id])
    @object = @comment.object if @comment
    if !check_permission!(@comment.user_id)
      redirect_to(:action => 'show_comment')
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
        flash_notice :form_comments_edit_success.t
        redirect_to(:action => 'show_comment', :id => @comment.id)
      end
    end
  end

  # Callback to destroy a comment.
  # Linked from: show_comment, show_observation
  # Redirects to show_observation.
  # Inputs: params[:id]
  # Outputs: none
  def destroy_comment
    @comment = Comment.find(params[:id])
    @object = @comment.object
    if !check_permission!(@comment.user_id)
      redirect_to(:action => 'show_comment')
    else
      if @comment.destroy
        Transaction.delete_comment(:id => @comment)
        flash_notice :form_comments_destroy_success.t
      else
        flash_error :form_comments_destroy_failed.t
      end
      redirect_to(:controller => @object.show_controller,
                  :action => @object.show_action, :id => @object.id)
    end
  end
end
