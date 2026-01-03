# frozen_string_literal: true

#  ==== Show, CRUD actions
#  index::
#  show::
#  new::
#  create::
#  edit::
#  update::
#  destroy::
#
class CommentsController < ApplicationController
  before_action :login_required
  before_action :store_location, only: [:show]

  # Bullet doesn't seem to be able to figure out that we cannot eager load
  # through polymorphic relations, so I'm just disabling it for these actions.
  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [:index]

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::Comments.default_order # :created_at
  end

  # ApplicationController uses this table to dispatch #index to a private method
  def index_active_params
    [:target, :pattern, :by_user, :for_user, :by, :q].freeze
  end

  # Shows comments by a given user, most recent first. (Linked from show_user.)
  def by_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_user].to_s,
      index_path: comments_path
    )
    return unless user

    query = create_query(:Comment, by_users: user)
    [query, {}]
  end

  # Shows comments for a given user's Observations, most recent first.
  # (Linked from show_user.)
  def for_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:for_user].to_s,
      index_path: comments_path
    )
    return unless user

    query = create_query(:Comment, for_user: user)
    [query, {}]
  end

  # Shows comments for a given object, most recent first. (Linked from the
  # "and more..." thingy at the bottom of truncated embedded comment lists.)
  def target
    return no_model unless (model = Comment.safe_model_from_name(params[:type]))
    return unless (target = find_or_goto_index(model, params[:target].to_s))

    query = create_query(:Comment, target: { type: target.class.name,
                                             id: target.id })
    [query, {}]
  end

  def no_model
    flash_error(:runtime_invalid.t(type: '"type"', value: params[:type].to_s))
    redirect_back_or_default(action: :index)
    [nil, {}]
  end

  def index_display_opts(opts, query)
    opts = {
      num_per_page: 25,
      # (Eager-loading of names might fail when comments start to apply to
      # objects other than observations.)
      include: [:target, :user]
    }.merge(opts)

    # Paginate by letter if sorting by user.
    if %w[user reverse_user].include?(query.params[:order_by])
      opts[:letters] = true
    end

    @full_detail = query.params[:target].present?

    opts
  end

  public

  ##############################################################################
  #
  #  :section: Show
  #
  ##############################################################################

  # Display comment by itself.
  # Linked from: show_<object>, index
  # Inputs: params[:id] (comment)
  # Outputs: @comment, @object
  def show
    return unless (@comment = find_comment!)

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Comment, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, Comment, params[:id]) and return
    end

    @target = @comment.target
    allowed_to_see!(@target)
  end

  private

  def find_comment!
    find_or_goto_index(Comment, params[:id].to_s)
  end

  # Make sure users can't see/add comments on objects they aren't allowed to
  # view!  Redirect and return +false+ if they can't, else return +true+.
  def allowed_to_see!(object)
    return true unless object.respond_to?(:is_reader?) &&
                       !object.is_reader?(@user) &&
                       !in_admin_mode?

    flash_error(:runtime_show_description_denied.t)
    show_flash_and_send_back(object.parent)
    false
  end

  public

  ##############################################################################
  #
  #  :section: CRUD actions
  #
  ##############################################################################

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
  def new
    return unless (@target = load_target(params[:type], params[:target])) &&
                  allowed_to_see!(@target)

    @comment = Comment.new(target: @target)

    respond_to do |format|
      format.html
      format.turbo_stream { render_modal_comment_form }
    end
  end

  def create
    return unless (@target = load_target(params[:type], params[:target])) &&
                  allowed_to_see!(@target)

    @comment = Comment.new(target: @target)
    @comment.attributes = permitted_comment_params if params[:comment]

    unless @comment.save
      flash_object_errors(@comment)
      reload_form and return
    end

    @comment.log_create
    flash_notice(:runtime_form_comments_create_success.t(id: @comment.id))

    refresh_comments_or_redirect_to_show
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
  def edit
    return unless (@comment = find_comment!)

    @target = comment_target
    return unless allowed_to_see!(@target)
    return unless check_permission_or_redirect!(@comment, @target)

    respond_to do |format|
      format.turbo_stream { render_modal_comment_form }
      format.html
    end
  end

  def update
    return unless (@comment = find_comment!)

    @target = comment_target
    return unless allowed_to_see!(@target) &&
                  check_permission_or_redirect!(@comment, @target)

    @comment.attributes = permitted_comment_params if params[:comment]
    reload_form and return unless comment_updated?

    refresh_comments_or_redirect_to_show
  end

  # Callback to destroy a comment.
  # Linked from: show_comment, show_object.
  # Redirects to show_object.
  # Inputs: params[:id]
  # Outputs: none
  def destroy
    return unless (@comment = find_comment!)

    @target = @comment.target
    if !permission!(@comment)
      # all html requests redirect to object show page
    elsif !@comment.destroy
      flash_error(:runtime_form_comments_destroy_failed.t(id: params[:id]))
    else
      @comment.log_destroy
      flash_notice(:runtime_form_comments_destroy_success.t(id: params[:id]))
    end

    refresh_comments_or_redirect_to_show
  end

  private

  # The identifier needs to be more specific for an edit form, because
  # we give users the option to edit any number of their own comments on a
  # show page. "comment" disambiguates :new, because :edit always has id
  def render_modal_comment_form
    render(Components::ModalForm.new(
             identifier: modal_identifier,
             title: modal_title,
             user: @user,
             model: @comment
           ))
  end

  def reload_modal_form
    render(partial: "shared/modal_form_reload",
           locals: { identifier: modal_identifier,
                     form_locals: { model: @comment } })
  end

  def modal_identifier
    case action_name
    when "new", "create"
      "comment"
    when "edit", "update"
      "comment_#{@comment.id}"
    end
  end

  def modal_title
    case action_name
    when "new", "create"
      helpers.comment_form_new_title(target: @target)
    when "edit", "update"
      helpers.comment_form_edit_title(target: @target)
    end
  end

  def permitted_comment_params
    params[:comment].permit([:summary, :comment])
  end

  def reload_form
    respond_to do |format|
      format.turbo_stream { reload_modal_form }
      format.html { render(:new) }
    end
  end

  def refresh_comments_or_redirect_to_show
    # Comment broadcasts are sent from the model
    respond_to do |format|
      # Simply send a head response for turbo here.
      format.turbo_stream { head(:ok) }
      format.html do
        redirect_to(@target.show_link_args)
      end
    end
  end

  def comment_target
    load_target(@comment.target_type, @comment.target_id)
  end

  def load_target(type, id)
    case type
    when "Observation"
      load_for_show_observation_or_goto_index(id)
    else
      target = Comment.find_object(type, id.to_s)
      redirect_back_or_default("/") unless target
      target
    end
  end

  def check_permission_or_redirect!(comment, target)
    return true if permission!(comment)

    show_flash_and_send_back(target)
    false
  end

  def comment_updated?
    if !@comment.changed?
      flash_notice(:runtime_no_changes.t)
      # changing this to `false`, because comment has not been changed.
      # Flash should render in modal (the `false` path) - AN 20231201
      false
    elsif !@comment.save
      flash_object_errors(@comment)
      false
    else
      @comment.log_update
      flash_notice(:runtime_form_comments_edit_success.t(id: @comment.id))
      true
    end
  end

  def show_flash_and_send_back(target)
    respond_to do |format|
      format.html do
        redirect_to(target.show_link_args) and return
      end
      # renders the flash in the modal
      format.turbo_stream do
        render(partial: "shared/modal_flash_update",
               locals: { identifier: modal_identifier }) and return
      end
    end
  end
end
