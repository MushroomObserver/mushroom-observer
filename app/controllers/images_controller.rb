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
#  show::
#  show_original::         show full_size image (for backwards compatibility)
#  next_image::
#  prev_image::
#  cast_vote::             change user's vote & go to next image
#
#  ==== Work With Images
#  add_image::             Upload images for observation.
#  edit_image::            Edit notes, etc. for image.
#  transform_image         Rotate or flip image
#  destroy_image::         Callback: destroy image.
#  remove_image::          Callback: remove image from observation.
#  reuse_image::           Choose images to add to observation.
#  remove_images::         Choose images to remove from observation.
#  remove_images_for_glossary_term Choose images to remove from GlossaryTerm.
#  license_updater::       Change copyright of many images.
#  bulk_vote_anonymity_updater:: Change anonymity of image votes in bulk.
#  bulk_filename_purge::   Purge all original image filenames from the database.
#  process_image::         (helper for add_image)
#
class ImagesController < ApplicationController
  before_action :login_required
  before_action :pass_query_params, except: [:index]
  before_action :disable_link_prefetching, except: [
    :new,
    :edit,
    :show
  ]

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
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Image, :by_user, user: user)
    show_selected_images(query)
  end

  # Display matrix of Image's attached to a given project.
  def images_for_project
    project = find_or_goto_index(Project, params[:id].to_s)
    return unless project

    query = create_query(:Image, :for_project, project: project)
    show_selected_images(query, always_index: 1)
  end

  # Display matrix of images whose notes, names, etc. match a string pattern.
  def image_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
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
      include: [:user, { observations: :name }, :subjects, :best_glossary_terms,
                :glossary_terms, :image_votes]
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
  #
  #  :section: Work With Images
  #
  ##############################################################################

  def new
    return unless (@observation = find_observation!)

    check_observation_permission!
    @image = rough_cut_image
    @licenses = current_license_names_and_ids
    init_project_vars_for_add_or_edit(@observation)
  end

  def create
    return unless (@observation = find_observation!)

    check_observation_permission!
    @image = rough_cut_image
    @licenses = current_license_names_and_ids
    init_project_vars_for_add_or_edit(@observation)
    create_image
  end

  private

  def find_observation!
    find_or_goto_index(Observation, params[:id].to_s)
  end

  def check_observation_permission!
    redirect_with_query(permanent_observation_path(id: @observation.id)) unless
      check_permission!(@observation)
  end

  def rough_cut_image
    @image = Image.new
    @image.license = @user.license
    @image.copyright_holder = @user.legal_name
    @image.user = @user
    # Set the default date to the date of the observation
    # Don't know how to correctly test this.
    @image.when = @observation.when
    @image
  end

  def create_image
    if params[:upload].blank?
      flash_warning(:runtime_no_changes.t)
    else
      args = params[:image]
      i = 1
      while i < 5 || params[:upload]["image#{i}"].present?
        process_image(args, params[:upload]["image#{i}"])
        i += 1
      end
    end
    redirect_with_query(permanent_observation_path(id: @observation.id))
  end

  def process_image(args, upload)
    return if upload.blank?

    @image = Image.new(args.permit(whitelisted_image_args))
    @image.created_at = Time.current
    @image.updated_at = @image.created_at
    @image.user       = @user
    @image.image      = upload
    @image.save

    # The 1st save (or !save) puts the image's original filename in the db,
    # whether or not the user wants it.  So if we don't want it,
    # we must empty it and save a 2nd time.
    @image.original_name = "" if @user.keep_filenames == "toss"
    return flash_object_errors(@image) unless @image.save

    add_image_to_observation!
  end

  def add_image_to_observation!
    return revert_image_name_and_flash_errors unless
      @image.process_image(strip: @observation.gps_hidden)

    @observation.add_image(@image)
    @image.log_create_for(@observation)
    name = @image.original_name
    name = "##{@image.id}" if name.empty?
    flash_notice(:runtime_image_uploaded_image.t(name: name))
    update_related_projects(@image, params[:project])
  end

  def revert_image_name_and_flash_errors
    name = @image.original_name
    name = "???" if name.empty?
    flash_error(:runtime_image_invalid_image.t(name: name))
    flash_object_errors(@image)
  end

  def update_related_projects(img, checks)
    return false unless checks

    # Here's the problem: User can add image to obs he doesn't own
    # if it is attached to one of his projects.
    # Observation can be attached to other projects, too,
    # though, including ones the user isn't a member of.
    # We want the image to be attached even to these projects by default,
    # however we want to give the user the ability NOT to attach his images
    # to these projects which he doesn't belong to.
    # This means we need to consider checkboxes not only of  user's projects,
    # but also all  projects of the observation, as well.  Once it is detached
    # from one of these projects the user isn't on,
    # the checkbox will no longer show
    # up on the edit_image form, preventing a user from attaching images to
    # projects she doesn't belong to...
    # except in the very strict case of uploading images for
    # an observation which belongs to a project he doesn't belong to.
    projects = @user.projects_member
    img.observations.each do |obs|
      obs.projects.each do |project|
        projects << project unless projects.include?(project)
      end
    end

    attach_images_to_projects_and_flash_notices(img, projects, checks)
  end

  def attach_images_to_projects_and_flash_notices(img, projects, checks)
    any_changes = false
    projects.each do |project|
      before = img.projects.include?(project)
      after = checks["id_#{project.id}"] == "1"
      next if before == after

      if after
        project.add_image(img)
        flash_notice(:attached_to_project.t(object: :image,
                                            project: project.title))
      else
        project.remove_image(img)
        flash_notice(:removed_from_project.t(object: :image,
                                             project: project.title))
      end
      any_changes = true
    end
    any_changes
  end

  public

  ##############################################################################

  # Form for editing date/license/notes on an image.
  # Linked from: show_image/original
  # Inputs: params[:id] (image)
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Outputs: @image, @licenses
  def edit
    return unless (@image = find_image!)

    @licenses = current_license_names_and_ids
    check_image_permission!
    init_project_vars_for_add_or_edit(@image)
  end

  def update
    return unless (@image = find_image!)

    @licenses = current_license_names_and_ids
    check_image_permission!

    @image.attributes = whitelisted_image_params

    if image_or_projects_updated
      redirect_with_query(action: "show", id: @image.id)
    else
      init_project_vars_for_reload(@image)
    end
  end

  private

  def current_license_names_and_ids
    License.current_names_and_ids(@image.license)
  end

  def check_image_permission!
    redirect_with_query(action: "show", id: @image) unless
      check_permission!(@image)
  end

  def image_or_projects_updated
    if !image_data_changed?
      update_projects_and_flash_notice!
      true
    elsif !@image.save
      flash_object_errors(@image)
      false
    else
      @image.log_update
      flash_notice(:runtime_image_edit_success.t(id: @image.id))
      update_related_projects(@image, params[:project])
      true
    end
  end

  def image_data_changed?
    @image.when_changed? ||
      @image.notes_changed? ||
      @image.copyright_holder_changed? ||
      @image.original_name_changed? ||
      @image.license_id_changed?
  end

  def update_projects_and_flash_notice!
    if update_related_projects(@image, params[:project])
      flash_notice(:runtime_image_edit_success.t(id: @image.id))
    else
      flash_notice(:runtime_no_changes.t)
    end
  end

  def init_project_vars_for_add_or_edit(obs_or_img)
    @projects = User.current.projects_member(order: :title)
    @project_checks = {}
    obs_or_img.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_project_vars_for_reload(obs_or_img)
    # (Note: In practice, this is never called for add_image,
    # so obs_or_img is always an image.)
    @projects = User.current.projects_member(order: :title)
    @project_checks = {}
    obs_or_img.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
    end
    @projects.each do |proj|
      @project_checks[proj.id] = begin
                                   params[:project]["id_#{proj.id}"] == "1"
                                 rescue StandardError
                                   false
                                 end
    end
  end

  public

  ##############################################################################

  # Callback to destroy an image.
  # Linked from: show_image/original
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

  ##############################################################################

  def whitelisted_image_params
    params.require(:image).permit(whitelisted_image_args)
  end
end
