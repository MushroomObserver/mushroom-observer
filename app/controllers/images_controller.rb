# frozen_string_literal: true

#
#  = Images Controller
#
#  == Actions
#
#  index::
#  show::                  can use params[:flow] :next, :prev
#  new::                   Upload images for observation.
#  edit::                  Edit notes, etc. for image.
#  create::                New form commits here
#  update::                Edit form commits here
#  destroy::               Callback: destroy image.
#
#  == Helper Methods
#
#  process_image::         (helper for add_image)
#
class ImagesController < ApplicationController
  before_action :login_required
  # disable cop because index is defined in ApplicationController
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :pass_query_params, except: [:index]
  before_action :disable_link_prefetching, except: [:show]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  ##############################################################################
  #
  # index::

  # ApplicationController uses this table to dispatch #index to a private method
  @index_subaction_param_keys = [
    :advanced_search,
    :pattern,
    :by_user,
    :for_project,
    :by
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results
  }.freeze

  #############################################

  private # private methods used by #index

  def default_index_subaction
    list_all
  end

  # Display matrix of images, most recent first.
  def list_all
    return render_too_many_results if too_many_results
    return index_query_results if params.include?(:by)

    query = create_query(:Image, :all, by: default_sort_order)
    show_selected_images(query)
  end

  def too_many_results
    params[:page].to_s.to_i > 1000
  end

  def render_too_many_results
    render(
      status: :too_many_requests,
      content_type: "text/plain",
      plain: <<-TOO_MANY_RESULTS.squish
        Your queries are killing our server.
        There are much better ways to scrape the images
        from our site.
        Please contact the webmaster.
        And please stop hammering our server!
      TOO_MANY_RESULTS
    )
  end

  def default_sort_order
    ::Query::ImageBase.default_order
  end

  # Display matrix of selected images, based on current Query.
  def index_query_results
    query = find_or_create_query(:Image, by: params[:by])
    show_selected_images(query, id: params[:id].to_s, always_index: true)
  end

  # Display matrix of images by a given user.
  def by_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_user].to_s,
      index_path: images_path
    )
    return unless user

    query = create_query(:Image, :by_user, user: user)
    show_selected_images(query)
  end

  # Display matrix of Image's attached to a given project.
  def for_project
    project = find_or_goto_index(Project, params[:for_project].to_s)
    return unless project

    query = create_query(:Image, :for_project, project: project)
    show_selected_images(query, always_index: 1)
  end

  # Display matrix of images whose notes, names, etc. match a string pattern.
  def pattern
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) &&
       (image = Image.safe_find(pattern))
      redirect_to(action: "show", id: image.id)
    else
      query = create_query(:Image, :pattern_search, pattern: pattern)
      show_selected_images(query)
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search
    return if handle_advanced_search_invalid_q_param?

    query = find_query(:Image)
    show_selected_images(query)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(search_advanced_path)
  end

  # Show selected search results as a matrix with "list_images" template.
  def show_selected_images(query, args = {})
    store_query_in_session(query)
    @view = view_context ## Needed for matrix view helepr

    # I can't figure out why ActiveRecord is not eager-loading all the names.
    # When I do an explicit test (load the first 100 images) it eager-loads
    # about 90%, but for some reason misses 10%, and always the same 10%, but
    # apparently with no rhyme or reason. -JPH 20100204
    args = {
      action: "index",
      matrix: true,
      include: [:user, { observations: :name }, :profile_users,
                :thumb_glossary_terms, :glossary_terms, :image_votes]
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = SORTING_LINKS

    # Paginate by letter if sorting by user.
    case query.params[:by]
    when "user", "reverse_user"
      args[:letters] = "users.login"
    # Paginate by letter if sorting by copyright holder.
    # when "copyright_holder", "reverse_copyright_holder"
    #   args[:letters] = "images.copyright_holder"
    # Paginate by letter if sorting by name.
    when "name", "reverse_name"
      args[:letters] = "names.sort_name"
    end

    show_index_of_objects(query, args)
  end

  SORTING_LINKS = [
    ["name",          :sort_by_name.t],
    ["original_name", :sort_by_filename.t],
    ["date",          :sort_by_date.t],
    ["user",          :sort_by_user.t],
    # ["copyright_holder", :sort_by_copyright_holder.t],
    ["created_at",    :sort_by_posted.t],
    ["updated_at",    :sort_by_updated_at.t],
    ["confidence",    :sort_by_confidence.t],
    ["image_quality", :sort_by_image_quality.t],
    ["num_views",     :sort_by_num_views.t]
  ].freeze

  public

  ##############################################################################
  #
  #  :section: Show Images
  #
  ##############################################################################

  # Show the 640x640 ("normal" size) version of image.
  # Linked from: thumbnails, next/prev_image, etc.
  # Inputs: params[:id] (image)
  # Outputs: @image
  def show
    store_location
    return false unless find_image!

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Image, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, Image, params[:id]) and return
    end

    set_default_size
    # Wait until here to create image search query to save server resources.
    # Otherwise we'd be creating a new search query for images for every single
    # show_observation request.  We know we came from an observation-type page
    # because that's the only time the "obs" param will be set (with obs id).
    set_image_query_params
    cast_user_vote!

    # Update view stats on image we're actually showing.
    update_view_stats(@image)
  end

  private

  def find_image!
    @image = Image.includes(show_image_includes).find_by(id: params[:id]) ||
             flash_error_and_goto_index(Image, params[:id])
  end

  def show_image_includes
    [
      { image_votes: :user }
    ]
  end

  def set_default_size
    # Decide which size to display.
    @default_size = @user ? @user.image_size : :medium
    @size = params[:size].blank? ? @default_size : params[:size].to_sym

    # Maybe make this size the default image size for this user.
    return unless @user &&
                  (@default_size != @size) &&
                  (params[:make_default] == "1")

    @user.image_size = @size
    @user.save_without_our_callbacks
    @default_size = @size
  end

  def set_image_query_params
    obs = params[:obs]
    # The outer search on observation won't be saved for robots, so no sense
    # in bothering with any of this.
    return unless obs.present? && obs.to_s.match(/^\d+$/) && !browser.bot?

    obs_query = find_or_create_query(:Observation)
    obs_query.current = obs
    img_query = create_query(:Image, :inside_observation,
                             observation: obs, outer: obs_query)
    query_params_set(img_query)
  end

  # change_vote directly, does not call public cast_vote below
  def cast_user_vote!
    return unless @user &&
                  (val = params[:vote]) &&
                  (val == "0" || (val = Image.validate_vote(val)))

    val = nil if val == "0"
    cur = @image.users_vote
    if cur != val
      anon = @user.votes_anonymous == :yes
      @image.change_vote(@user, val, anon: anon)
    end

    # Advance to next image automatically if "next" parameter set.
    goto_next_image if params[:next]
  end

  def goto_next_image
    query = find_or_create_query(Image)
    query.current = @image
    @image = query.current if query.index(@image) && (query = query.next)
  end

  public

  ##############################################################################

  # Callback to destroy an image.
  # Linked from: images/show
  # Inputs: params[:id] (image)
  # Redirects to list_images.
  def destroy
    @image = find_or_goto_index(Image, params[:id].to_s)
    return unless @image

    next_state = nil
    # decide where to redirect after deleting image
    if (this_state = find_query(:Image))
      query_params_set(this_state)
      this_state.current = @image
      next_state = this_state.next
    end
    delete_and_redirect(next_state)
  end

  private

  def delete_and_redirect(next_state = nil)
    return redirect_with_query(action: "show", id: @image.id) unless
      check_permission!(@image)

    @image.log_destroy
    @image.destroy
    flash_notice(:runtime_image_destroy_success.t(id: params[:id].to_s))
    return redirect_to(action: "index") unless next_state

    query_params_set(next_state)
    redirect_with_query(action: "show", id: next_state.current_id)
  end
end
