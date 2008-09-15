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
    :show_comments_for_user,
    :show_comments_by_user,
    :show_comment
  ]

  # Show list of latest comments.
  # Linked from: left-hand panel
  # Inputs: params[:page]
  # Outputs: @comments, @comment_pages
  def list_comments
    store_location
    session_setup
    @title = "Comments"
    @comment_pages, @comments = paginate(:comments,
       :order => "created desc", :per_page => 10)
  end

  # Shows comments for a given user, most recent first.
  # Linked from: left panel
  # View: list_comments
  # Inputs: params[:id] (user)
  # Outputs: @comments, @comment_pages
  def show_comments_for_user
    session_setup
    store_location
    for_user = User.find(params[:id])  # (don't use @user since that means something else everywhere else in code)
    @title = "Comments for %s" % for_user.legal_name

    # Get list of comments for objects that this user owns.
    observation_comment_ids = Comment.connection.select_values %(
      SELECT comments.id FROM comments
      LEFT OUTER JOIN observations ON object_id = observations.id AND object_type = "Observation"
      WHERE observations.user_id = #{for_user.id}
    )
    # (get other object types' comments here)

    # Get list of comment ids, sorted with most recently updated first.
    all_comment_ids = (
      observation_comment_ids
      # + name_comment_ids
      # + etc.
    ).uniq.sort_by {|x| -(x.to_i)}

    # Paginate list and load selected comments and the objects they refer to.
    @comment_pages, all_comment_ids = paginate_array(all_comment_ids, 10)
    @comments = Comment.find(:all, :include => :object,
      :conditions => ['id in (?)', all_comment_ids], :order => 'id desc')
    render(:action => 'list_comments')
  end

  # Shows comments for a given user, most recent first.
  # Linked from: left panel
  # View: list_comments
  # Inputs: params[:id] (user)
  # Outputs: @comments, @comment_pages
  def show_comments_by_user
    session_setup
    store_location
    by_user = User.find(params[:id]) # (don't use @user since that means something else throughout the code)
    @title = "Comments by %s" % by_user.legal_name
    @comment_pages, @comments = paginate(:comments,
      :order => "created desc", :conditions => "user_id = %s" % by_user.id,
      :per_page => 10)
    render(:action => 'list_comments')
  end

  # Display comment by itself.
  # Linked from: show_observation, list_comments
  # Inputs: params[:id] (comment)
  # Outputs: @comment, @object
  def show_comment
    store_location
    @comment = Comment.find(params[:id])
    @object = @comment.object
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
    if verify_user()
      pass_seq_params()
      @object = Comment.find_object(params[:type], params[:id])
      if request.method == :get
        @comment = Comment.new
        @comment.object = @object
      else
        @comment = Comment.new(params[:comment])
        @comment.created = Time.now
        @comment.user = @user
        @comment.object = @object
        if @comment.save
          @object.log("Comment added by #{@user.login}: #{@comment.summary}", true) \
            if @object.respond_to?(:log)
          flash_notice "Comment was successfully added."
          params = @comment.object_type == 'Observation' ? calc_search_params() : nil
          redirect_to(:controller => @object.show_controller,
            :action => @object.show_action, :id => @object.id,
            :params => params)
        else
          flash_object_errors(@comment)
        end
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
    if !check_user_id(@comment.user_id)
      render(:action => 'show_comment')
    elsif request.method == :post
      if !@comment.update_attributes(params[:comment]) || !@comment.save
        flash_object_errors(@comment)
      else
        @object.log("Comment updated by #{@user.login}: #{@comment.summary}", false) \
          if @object.respond_to?(:log)
        flash_notice "Comment was successfully updated."
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
    if !check_user_id(@comment.user_id)
      render(:action => 'show_comment')
    else
      object = @comment.object
      summary = @comment.summary
      if @comment.destroy
        object.log("Comment destroyed by #{@user.login}: #{sum}", false) \
          if @object.respond_to?(:log)
        flash_notice "Comment destroyed."
      else
        flash_error "Failed to destroy comment."
      end
      redirect_to(:controller => object.show_controller,
        :action => object.show_action, :id => object.id)
    end
  end
end
