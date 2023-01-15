# frozen_string_literal: true

#
#  = Images Controller
#
#  == Actions
#
#  ==== Searches and Indexes
#  index::                 Display a matrix of images:
#      (private methods)
#  list_images::           all images, by creation date descending
#  images_by_user::        by a given user
#  images_for_project      attached to a given project
#  image_search::          whose attributes match a string pattern
#  advanced_search::       matching Advanced Search results
#  index_image::           current query
#  show_selected_images::  search results
#
#  ==== Show Images
#  show::                  can use params[:flow] :next, :prev
#
#  ==== Work With Images
#  new::                   Upload images for observation.
#  edit::                  Edit notes, etc. for image.
#  create::                New form commits here
#  update::                Edit form commits here
#  destroy::               Callback: destroy image.
#  process_image::         (helper for add_image)
#
class ImagesController < ApplicationController
  before_action :login_required
  before_action :pass_query_params, except: [:index]
  before_action :disable_link_prefetching, except: [:show]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  def index # rubocop:disable Metrics/AbcSize
    if params[:advanced_search].present?
      advanced_search
    elsif params[:pattern].present?
      image_search
    elsif params[:by_user].present?
      images_by_user
    elsif params[:for_project].present?
      images_for_project
    elsif params[:by].present?
      index_image
    else
      list_images
    end
  end

  private

  # Display matrix of selected images, based on current Query.
  def index_image
    query = find_or_create_query(:Image, by: params[:by])
    show_selected_images(query, id: params[:id].to_s, always_index: true)
  end

  # Display matrix of images, most recent first.
  def list_images
    if params[:page].to_s.to_i > 1000
      render(
        status: :too_many_requests,
        content_type: "text/plain",
        plain: "Your queries are killing our server. " \
               "There are much better ways to scrape the images " \
               "from our site. " \
               "Please contact the webmaster." \
               "And please stop hammering our server!"
      )
      return
    end

    query = create_query(:Image, :all, by: :created_at)
    show_selected_images(query)
  end

  # Display matrix of images by a given user.
  def images_by_user
    user = if params[:by_user]
             find_or_goto_index(User, params[:by_user].to_s)
           else
             @user
           end
    return unless user

    query = create_query(:Image, :by_user, user: user)
    show_selected_images(query)
  end

  # Display matrix of Image's attached to a given project.
  def images_for_project
    project = find_or_goto_index(Project, params[:for_project].to_s)
    return unless project

    query = create_query(:Image, :for_project, project: project)
    show_selected_images(query, always_index: 1)
  end

  # Display matrix of images whose notes, names, etc. match a string pattern.
  def image_search
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
    @links ||= []

    # I can't figure out why ActiveRecord is not eager-loading all the names.
    # When I do an explicit test (load the first 100 images) it eager-loads
    # about 90%, but for some reason misses 10%, and always the same 10%, but
    # apparently with no rhyme or reason. -JPH 20100204
    args = {
      action: "index",
      matrix: true,
      include: [:user, { observations: :name }, :subjects,
                :glossary_term_thumbnails, :glossary_terms, :image_votes]
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = SORTING_LINKS

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Observation)

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
    return false unless (@image = find_image!)

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
    @votes = find_list_of_votes!

    # Update view stats on image we're actually showing.
    update_view_stats(@image)
  end

  private

  def find_image!
    find_or_goto_index(Image, params[:id].to_s)
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

  def find_list_of_votes!
    @image.image_votes.sort_by do |v|
      (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
    rescue StandardError
      "?"
    end
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
