#
#  = Image Controller
#
#  == Actions
#
#  ==== Searches and Indexes
#  list_images::
#  images_by_user::
#  image_search::
#  advanced_search::
#  index_image::
#  show_selected_images::
#
#  ==== Show Images
#  show_image::
#  next_image::
#  prev_image::
#  cast_vote::
#
#  ==== Work With Images
#  add_image::             Upload images for observation.
#  edit_image::            Edit notes, etc. for image.
#  destroy_image::         Callback: destroy image.
#  remove_image::          Callback: remove image from observation.
#  reuse_image::           Choose images to add to observation.
#  remove_images::         Choose images to remove from observation.
#  license_updater::       Change copyright of many images.
#  bulk_vote_anonymity_updater:: Change anonymity of image votes in bulk.
#  bulk_filename_purge::   Purge all original image filenames from the database.
#  process_image::         (helper for add_image)
#
#  ==== Test Actions
#  test_add_image::
#  test_add_image_report::
#  test_upload_image::
#  test_upload_speed::
#  test_process_image::    (helper for test_upload_image)
#  resize_image::          (helper for test_upload_speed)
#
################################################################################

class ImageController < ApplicationController
  before_action :login_required, except: [
    :advanced_search,
    :image_search,
    :images_by_user,
    :images_for_project,
    :index_image,
    :list_images,
    :next_image,
    :prev_image,
    :show_image,
    :show_original,
    :test_upload_speed
  ]

  before_action :disable_link_prefetching, except: [
    :add_image,
    :edit_image,
    :show_image
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Display matrix of selected images, based on current Query.
  def index_image # :nologin: :norobots:
    query = find_or_create_query(:Image, by: params[:by])
    show_selected_images(query, id: params[:id].to_s, always_index: true)
  end

  # Display matrix of images, most recent first.
  def list_images # :nologin:
    query = create_query(:Image, :all, by: :created_at)
    show_selected_images(query)
  end

  # Display matrix of images by a given user.
  def images_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      query = create_query(:Image, :by_user, user: user)
      show_selected_images(query)
    end
  end

  # Display matrix of Image's attached to a given project.
  def images_for_project
    if project = find_or_goto_index(Project, params[:id].to_s)
      query = create_query(:Image, :for_project, project: project)
      show_selected_images(query, always_index: 1)
    end
  end

  # Display matrix of images whose notes, names, etc. match a string pattern.
  def image_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (image = Image.safe_find(pattern))
      redirect_to(action: "show_image", id: image.id)
    else
      query = create_query(:Image, :pattern_search, pattern: pattern)
      show_selected_images(query)
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search # :nologin: :norobots:
    query = find_query(:Image)
    show_selected_images(query)
  rescue StandardError => err
    flash_error(err.to_s) if err.present?
    redirect_to(controller: "observer", action: "advanced_search")
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
      action: "list_images",
      matrix: true,
      include: [:user, { observations: :name }]
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
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
    ]

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Observation)

    # Paginate by letter if sorting by user.
    if (query.params[:by] == "user") ||
       (query.params[:by] == "reverse_user")
      args[:letters] = "users.login"
    # Paginate by letter if sorting by copyright holder.
    elsif (query.params[:by] == "copyright_holder") ||
          (query.params[:by] == "reverse_copyright_holder")
      args[:letters] = "images.copyright_holder"
    # Paginate by letter if names are included in query.
    elsif query.uses_table?(:names)
      args[:letters] = "names.sort_name"
    end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show Images
  #
  ##############################################################################

  # Show the 640x640 ("normal" size) version of image.
  # Linked from: thumbnails, next/prev_image, etc.
  # Inputs: params[:id] (image)
  # Outputs: @image
  def show_image # :nologin: :prefetch:
    store_location
    return false unless @image = find_or_goto_index(Image, params[:id].to_s)

    pass_query_params

    # Decide which size to display.
    @default_size = @user ? @user.image_size : :medium
    @size = params[:size].blank? ? @default_size : params[:size].to_sym

    # Make this size the default image size for this user.
    if @user && (@default_size != @size) && (params[:make_default] == "1")
      @user.image_size = @size
      @user.save_without_our_callbacks
      @default_size = @size
    end

    # Wait until here to create this search query to save server resources.
    # Otherwise we'd be creating a new search query for images for every single
    # show_observation request.  We know we came from an observation-type page
    # because that's the only time the "obs" param will be set (with obs id).
    obs = params[:obs]
    if obs.present? &&
       # The outer search on observation won't be saved for robots, so no sense
       # in bothering with any of this.
       !browser.bot?
      obs_query = find_or_create_query(:Observation)
      obs_query.current = obs
      img_query = create_query(:Image, :inside_observation,
                               observation: obs, outer: obs_query)
      query_params_set(img_query)
    end

    # Cast user's vote if passed in "vote" parameter.
    if @user &&
       (val = params[:vote]) &&
       (val == "0" || (val = Image.validate_vote(val)))
      val = nil if val == "0"
      cur = @image.users_vote
      if cur != val
        anon = @user.votes_anonymous == :yes
        @image.change_vote(@user, val, anon)
      end

      # Advance to next image automatically if "next" parameter set.
      if params[:next]
        query = find_or_create_query(Image)
        query.current = @image
        @image = query.current if query.index(@image) && (query = query.next)
      end
    end

    # Grab list of votes.
    @votes = @image.image_votes.sort_by do |v|
      begin
        (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
      rescue StandardError
        "?"
      end
    end

    # Update view stats on image we're actually showing.
    update_view_stats(@image)
  end

  # For backwards compatibility.
  def show_original
    redirect_to(action: "show_image", size: "full_size", id: params[:id].to_s)
  end

  # Go to next image: redirects to show_image.
  def next_image # :nologin: :norobots:
    redirect_to_next_object(:next, Image, params[:id].to_s)
  end

  # Go to previous image: redirects to show_image.
  def prev_image # :nologin: :norobots:
    redirect_to_next_object(:prev, Image, params[:id].to_s)
  end

  # Change user's vote and go to next image.
  def cast_vote # :norobots:
    if image = find_or_goto_index(Image, params[:id].to_s)
      val = image.change_vote(@user, params[:value])
      if params[:next]
        redirect_to_next_object(:next, Image, params[:id].to_s)
      else
        redirect_with_query(action: "show_image", id: id)
      end
    end
  end

  ##############################################################################
  #
  #  :section: Work With Images
  #
  ##############################################################################

  # Form for uploading and adding images to an observation.
  # Linked from: show_observation, reuse_image,
  #   naming/create, and naming/edit (via _show_images partial)
  # Inputs: params[:id] (observation)
  #   params[:upload][:image1-4]
  #   params[:image][:copyright_holder]
  #   params[:image][:when]
  #   params[:image][:license_id]
  #   params[:image][:notes]
  # Outputs: @image, @observation
  #   @licenses     (options for license select menu)
  # Redirects to show_observation.
  def add_image # :prefetch: :norobots:
    pass_query_params
    if @observation = find_or_goto_index(Observation, params[:id].to_s)
      if !check_permission!(@observation)
        redirect_with_query(controller: "observer",
                            action: "show_observation", id: @observation.id)
      elsif request.method != "POST"
        @image = Image.new
        @image.license = @user.license
        @image.copyright_holder = @user.legal_name
        @image.user = @user
        # Set the default date to the date of the observation
        # Don't know how to correctly test this.
        @image.when = @observation.when
        @licenses = License.current_names_and_ids(@image.license)
        init_project_vars_for_add_or_edit(@observation)
      elsif params[:upload].blank?
        flash_warning(:runtime_no_changes.t)
        redirect_with_query(controller: "observer",
                            action: "show_observation", id: @observation.id)
      else
        args = params[:image]
        i = 1
        while i < 5 || params[:upload]["image#{i}"].present?
          process_image(args, params[:upload]["image#{i}"])
          i += 1
        end
        redirect_with_query(controller: "observer",
                            action: "show_observation", id: @observation.id)
      end
    end
  end

  def process_image(args, upload)
    if upload.present?
      @image = Image.new(args.permit(whitelisted_image_args))
      @image.created_at = Time.now
      @image.updated_at = @image.created_at
      @image.user       = @user
      @image.image      = upload
      @image.save

      # The 1st save (or !save) puts the image's original filename in the db,
      # whether or not the user wants it.  So if we don't want it,
      # we must empty it and save a 2nd time.
      @image.original_name = "" if @user.keep_filenames == :toss
      return flash_object_errors(@image) unless @image.save

      if !@image.process_image(@observation.gps_hidden)
        logger.error("Unable to upload image")
        name = @image.original_name
        name = "???" if name.empty?
        flash_error(:runtime_image_invalid_image.t(name: name))
        flash_object_errors(@image)
      else
        @observation.add_image(@image)
        @observation.log_create_image(@image)
        name = @image.original_name
        name = "##{@image.id}" if name.empty?
        flash_notice(:runtime_image_uploaded_image.t(name: name))
        update_projects(@image, params[:project])
      end
    end
  end

  # Form for editing date/license/notes on an image.
  # Linked from: show_image/original
  # Inputs: params[:id] (image)
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Outputs: @image, @licenses
  def edit_image # :prefetch: :norobots:
    pass_query_params
    if @image = find_or_goto_index(Image, params[:id].to_s)
      @licenses = License.current_names_and_ids(@image.license)
      if !check_permission!(@image)
        redirect_with_query(action: "show_image", id: @image)
      elsif request.method != "POST"
        init_project_vars_for_add_or_edit(@image)
      else
        @image.attributes = whitelisted_image_params
        xargs = {}
        xargs[:set_date] = @image.when if @image.when_changed?
        xargs[:set_notes] = @image.notes if @image.notes_changed?
        xargs[:set_copyright_holder] = @image.copyright_holder if @image.copyright_holder_changed?
        xargs[:set_original_name] = @image.original_name if @image.original_name_changed?
        xargs[:set_license] = @image.license if @image.license_id_changed?
        done = false
        if xargs.empty?
          if update_projects(@image, params[:project])
            flash_notice :runtime_image_edit_success.t(id: @image.id)
          else
            flash_notice(:runtime_no_changes.t)
          end
          done = true
        elsif !@image.save
          flash_object_errors(@image)
        else
          xargs[:id] = @image
          @image.log_update
          flash_notice :runtime_image_edit_success.t(id: @image.id)
          update_projects(@image, params[:project])
          done = true
        end
        if done
          redirect_with_query(action: "show_image", id: @image.id)
        else
          init_project_vars_for_reload(@image)
        end
      end
    end
  end

  def init_project_vars_for_add_or_edit(obs_or_img)
    @projects = User.current.projects_member.sort_by(&:title)
    @project_checks = {}
    for proj in obs_or_img.projects
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_project_vars_for_reload(obs_or_img)
    # (Note: In practice, this is never called for add_image,
    # so obs_or_img is always an image.)
    @projects = User.current.projects_member.sort_by(&:title)
    @project_checks = {}
    for proj in obs_or_img.projects
      @projects << proj unless @projects.include?(proj)
    end
    for proj in @projects
      @project_checks[proj.id] = begin
                                   params[:project]["id_#{proj.id}"] == "1"
                                 rescue StandardError
                                   false
                                 end
    end
  end

  def update_projects(img, checks)
    any_changes = false
    if checks

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
      for obs in img.observations
        for project in obs.projects
          projects << project unless projects.include?(project)
        end
      end

      for project in projects
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
    end
    any_changes
  end

  # Callback to destroy an image.
  # Linked from: show_image/original
  # Inputs: params[:id] (image)
  # Redirects to list_images.
  def destroy_image # :norobots:
    if @image = find_or_goto_index(Image, params[:id].to_s)
      next_state = nil
      # decide where to redirect after deleting image
      if this_state = find_query(:Image)
        query_params_set(this_state)
        this_state.current = @image
        next_state = this_state.next
      end
      if !check_permission!(@image)
        redirect_with_query(action: "show_image", id: @image.id)
      else
        @image.log_destroy
        @image.destroy
        flash_notice(:runtime_image_destroy_success.t(id: params[:id].to_s))
        if next_state
          query_params_set(next_state)
          redirect_with_query(action: "show_image", id: next_state.current_id)
        else
          redirect_to(action: "list_images")
        end
      end
    end
  end

  # Callback to remove a single image from an observation.
  # Linked from: observer/edit_observation
  # Inputs: params[:image_id], params[:observation_id]
  # Redirects to show_observation.
  def remove_image # :norobots:
    pass_query_params
    if @image = find_or_goto_index(Image, params[:image_id]) and
       @observation = find_or_goto_index(Observation, params[:observation_id])
      if !check_permission!(@observation)
        flash_error(:runtime_image_remove_denied.t(id: @image.id))
      elsif !@observation.images.include?(@image)
        flash_error(:runtime_image_remove_missing.t(id: @image.id))
      else
        @observation.remove_image(@image)
        @observation.log_remove_image(@image)
        flash_notice(:runtime_image_remove_success.t(id: @image.id))
      end
      redirect_with_query(controller: "observer",
                          action: "show_observation", id: @observation.id)
    end
  end

  def serve_reuse_form(params)
    if params[:all_users] == "1"
      @all_users = true
      query = create_query(:Image, :all, by: :updated_at)
    else
      query = create_query(:Image, :by_user, user: @user, by: :updated_at)
    end
    @layout = calc_layout_params
    @pages = paginate_numbers(:page, @layout["count"])
    @objects = query.paginate(@pages,
                              include: [:user, { observations: :name }])
  end

  def look_for_image(method, params)
    result = nil
    if (method == "POST") || params[:img_id].present?
      result = Image.safe_find(params[:img_id])
      flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id])) unless result
    end
    result
  end

  def reuse_image_for_glossary_term
    pass_query_params
    @object = GlossaryTerm.safe_find(params[:id])
    image = look_for_image(request.method, params)
    if image
      redirect_to(@object.process_image_reuse(image, query_params))
    else
      serve_reuse_form(params)
    end
  end

  # Browse through matrix of recent images to let a user reuse an image
  # they've already uploaded for another observation.
  # Linked from: observer/show_observation and account/profile
  # Inputs:
  #   params[:mode]       "observation" or "profile"
  #   params[:obs_id]     (observation)
  #   params[:img_id]     (image)
  #   params[:all_users]  "0" or "1"
  # Outputs:
  #   @mode           :observation or :profile
  #   @all_users      true or false
  #   @pages          paginator for images
  #   @objects        Array of images
  #   @observation    observation (if in observation mode)
  #   @layout         layout parameters
  # Posts to the same action.  Redirects to show_observation or show_user.
  def reuse_image # :norobots:
    pass_query_params
    @mode = params[:mode].to_sym
    @observation = Observation.safe_find(params[:obs_id]) if @mode == :observation
    done = false

    # Make sure user owns the observation.
    if (@mode == :observation) &&
       !check_permission!(@observation)
      redirect_with_query(controller: "observer",
                          action: "show_observation", id: @observation.id)
      done = true

    # User entered an image id by hand or clicked on an image.
    elsif (request.method == "POST") ||
          params[:img_id].present?
      image = Image.safe_find(params[:img_id])
      if !image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))

      elsif @mode == :observation
        # Add image to observation.
        @observation.add_image(image)
        @observation.log_reuse_image(image)
        if @observation.gps_hidden
          error = image.strip_gps!
          flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
        end
        redirect_with_query(controller: "observer",
                            action: "show_observation", id: @observation.id)
        done = true

      else
        # Change user's profile image.
        if @user.image == image
          flash_notice(:runtime_no_changes.t)
        else
          @user.update(image: image)
          flash_notice(:runtime_image_changed_your_image.t(id: image.id))
        end
        redirect_to(controller: "observer", action: "show_user",
                    id: @user.id)
        done = true
      end
    end

    # Serve form.
    unless done
      if params[:all_users] == "1"
        @all_users = true
        query = create_query(:Image, :all, by: :updated_at)
      else
        query = create_query(:Image, :by_user, user: @user, by: :updated_at)
      end
      @layout = calc_layout_params
      @pages = paginate_numbers(:page, @layout["count"])
      @objects = query.paginate(@pages,
                                include: [:user, { observations: :name }])
    end
  end

  # Form used to remove one or more images from an observation (not destroy!)
  # Linked from: show_observation
  # Inputs:
  #   params[:id]                  (observation)
  #   params[:selected][image_id]  (value of "yes" means delete)
  # Outputs: @observation
  # Redirects to show_observation.
  def remove_images # :norobots:
    remove_images_from_object(Observation, params)
  end

  def remove_images_from_object(target_class, params)
    pass_query_params
    @object = find_or_goto_index(target_class, params[:id].to_s)
    return unless @object

    if check_permission!(@object)
      if request.method == "POST" && (images = params[:selected])
        images.each do |image_id, do_it|
          next unless do_it == "yes"

          next unless image = Image.safe_find(image_id)

          @object.remove_image(image)
          @object.log_remove_image(image)
          flash_notice(:runtime_image_remove_success.t(id: image_id))
        end
        redirect_with_query(controller: target_class.show_controller,
                            action: target_class.show_action, id: @object.id)
      end
    else
      redirect_with_query(controller: target_class.show_controller,
                          action: target_class.show_action, id: @object.id)
    end
  end

  def remove_images_for_glossary_term
    remove_images_from_object(GlossaryTerm, params)
  end

  # Used by show_image to rotate and flip image.
  def transform_image # :norobots:
    pass_query_params
    if image = find_or_goto_index(Image, params[:id].to_s)
      if check_permission!(image)
        if params[:op] == "rotate_left"
          image.transform(:rotate_left)
          flash_notice(:image_show_transform_note.t)
        elsif params[:op] == "rotate_right"
          image.transform(:rotate_right)
          flash_notice(:image_show_transform_note.t)
        elsif params[:op] == "mirror"
          image.transform(:mirror)
          flash_notice(:image_show_transform_note.t)
        else
          flash_error("Invalid operation #{params[:op].inspect}")
        end
      end
      if params[:size].blank? ||
         params[:size].to_sym == (@user ? @user.image_size : :medium)
        redirect_with_query(action: "show_image", id: image)
      else
        redirect_with_query(action: "show_image", id: image,
                            size: params[:size])
      end
    end
  end

  # Tabular form that lets user change licenses of their images.  The table
  # groups all the images of a given copyright holder and license type into
  # a single row.  This lets you change all Rolf's licenses in one stroke.
  # Linked from: account/prefs
  # Inputs:
  #   params[:updates][n][:old_id]      (old license_id)
  #   params[:updates][n][:new_id]      (new license_id)
  #   params[:updates][n][:old_holder]  (old copyright holder)
  #   params[:updates][n][:new_holder]  (new copyright holder)
  # Outputs: @data
  #   @data[n]["copyright_holder"]  Person who actually holds copyright.
  #   @data[n]["license_count"]     Number of images this guy holds with
  #                                 this type of license.
  #   @data[n]["license_id"]        ID of current license.
  #   @data[n]["license_name"]      Name of current license.
  #   @data[n]["licenses"]          Options for select menu.
  def license_updater # :norobots:
    # Process any changes.
    process_license_changes if request.method == "POST"

    # Gather data for form.
    @data = Image.connection.select_all(%(
      SELECT COUNT(*) AS license_count, copyright_holder, license_id
      FROM images
      WHERE user_id = #{@user.id.to_i}
      GROUP BY copyright_holder, license_id
    )).to_a
    @data.each do |datum|
      next unless (license = License.safe_find(datum["license_id"].to_i))

      datum["license_name"] = license.display_name
      datum["licenses"]     = License.current_names_and_ids(license)
    end
  end

  private # private methods used by license updater ############################

  def process_license_changes
    params[:updates].values.each do |row|
      next unless row_changed?(row)

      images_to_update = Image.where(
        user: @user, license: row[:old_id], copyright_holder: row[:old_holder]
      )
      update_licenses_history(images_to_update, row[:old_holder], row[:old_id])

      # Update the license info in the images
      # Disable cop because we want to update all relevant records with
      # a single SELECT. Otherwise license updating would take too long
      # for users with many (e.g. thousands) of images
      # rubocop:disable Rails/SkipsModelValidations
      images_to_update.update_all(license_id: row[:new_id],
                                  copyright_holder: row[:new_holder])
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def row_changed?(row)
    row[:old_id] != row[:new_id] ||
      row[:old_holder] != row[:new_holder]
  end

  # Add license change records with raw SQL in order to use a single INSERT.
  # Otherwise updating would take too long for many (e.g. thousands) of images
  def update_licenses_history(images_to_update, old_holder, old_license_id)
    data = images_to_update.pluck(:id, :when)

    # Prevent SQL injection
    safe_old_holder = Image.connection.quote(old_holder)
    safe_old_license_id = old_license_id.to_i
    values = data.map do |img_id, img_when|
      "(#{@user.id}, NOW(), 'Image', #{img_id}, #{img_when.year}, "\
      "#{safe_old_holder}, #{safe_old_license_id})"
    end.join(",\n")

    # brakeman generates what appears to be a false positive SQL injection
    # warning.  See https://github.com/presidentbeef/brakeman/issues/1231
    Image.connection.insert(%(
      INSERT INTO copyright_changes
        (user_id, updated_at, target_type, target_id, year, name, license_id)
      VALUES
        #{values}
    ))
  end

  public # end private methods used by license updater #########################

  # Bulk update anonymity of user's image votes.
  # Input: params[:commit] - which button user pressed
  # Outputs:
  #   @num_anonymous - number of existing anonymous votes
  #   @num_public    - number of existing puclic votes
  def bulk_vote_anonymity_updater
    if request.method == "POST"
      submit = params[:commit]
      if submit == :image_vote_anonymity_make_anonymous.l
        ImageVote.connection.update %(
          UPDATE image_votes SET anonymous = TRUE WHERE user_id = #{@user.id}
        )
        flash_notice(:image_vote_anonymity_made_anonymous.t)
      elsif submit == :image_vote_anonymity_make_public.l
        ImageVote.connection.update %(
          UPDATE image_votes SET anonymous = FALSE WHERE user_id = #{@user.id}
        )
        flash_notice(:image_vote_anonymity_made_public.t)
      else
        flash_error(:image_vote_anonymity_invalid_submit_button.l(label: submit))
      end
      redirect_to(controller: "account", action: "prefs")
    else
      @num_anonymous = ImageVote.connection.select_value %(
        SELECT count(id) FROM image_votes WHERE user_id = #{@user.id} AND anonymous
      )
      @num_public = ImageVote.connection.select_value %(
        SELECT count(id) FROM image_votes WHERE user_id = #{@user.id} AND !anonymous
      )
    end
  end

  def bulk_filename_purge
    Image.connection.update(%(
      UPDATE images SET original_name = '' WHERE user_id = #{User.current_id}
    ))
    flash_notice(:prefs_bulk_filename_purge_success.t)
    redirect_to(controller: :account, action: :prefs)
  end

  ##############################################################################
  #
  #  :section: Stuff for Mushroom App
  #
  ##############################################################################

  def images_for_mushroom_app # :nologin: :norobots:
    minimum_confidence = params[:minimum_confidence].presence || 1.5
    minimum_quality = params[:minimum_quality].presence || 2.0
    target_width = params[:target_width].presence || 400
    target_height = params[:target_height].presence || 600
    minimum_width = params[:minimum_width].presence || target_width
    minimum_height = params[:minimum_height].presence || target_height
    confidence_reward = params[:confidence_reward].presence || 2.0
    quality_reward = params[:quality_reward].presence || 1.0
    ratio_penalty = params[:ratio_penalty].presence || 0.5

    # Last term in ORDER BY spec below penalizes images of the wrong aspect ratio.
    # If we wanted 600x400 it will penalize 400x400 images by "ratio_penalty".
    ratio_penalty = ratio_penalty.to_f / Math.log10(600.0 / 400)

    names = get_list_of_names(params[:names])
    names = names.map { |n| "'" + n.gsub(/'/, '\\\'') + "'" }.join(",")

    data = Name.connection.select_rows(%(
      SELECT y.name, y.id, y.width, y.height
      FROM (
        SELECT x.text_name AS name, i.id AS id, i.width AS width, i.height AS height
        FROM (
          SELECT DISTINCT n1.text_name AS text_name, n2.id AS name_id
          FROM names n1
          JOIN names n2 ON IF(n1.synonym_id IS NULL, n2.id = n1.id, n2.synonym_id = n1.synonym_id)
          WHERE n1.rank = #{Name.ranks[:Species]} AND n1.text_name IN (#{names})
        ) AS x, observations o, images i
        WHERE o.name_id = x.name_id
          AND i.id = o.thumb_image_id
          AND o.vote_cache >= #{minimum_confidence}
          AND i.vote_cache >= #{minimum_quality}
          AND i.width >= #{minimum_width} AND i.height >= #{minimum_height}
        ORDER BY
          o.vote_cache * #{confidence_reward} +
          i.vote_cache * #{quality_reward} -
          ABS(LOG(width/height) - #{Math.log10(target_width.to_f / target_height)}) * #{ratio_penalty} DESC
      ) AS y
      GROUP BY y.name
    ))

    if params[:test]
      render_test_image_report(data)
    else
      render_image_csv_file(data)
    end
  rescue StandardError => e
    render(plain: e.to_s, layout: false, status: :internal_server_error)
  end

  def render_test_image_report(data)
    report = data.map do |name, id|
      "<img src='/images/320/#{id}.jpg'/><br/><i>#{name}</i><br/>"
    end.join("<br/>\n")
    render(plain: report)
  end

  def render_image_csv_file(data)
    report = CSV.generate(col_sep: "\t") do |csv|
      csv << ["name", "image id", "image width", "image height"]
      data.each do |name, id, width, height|
        csv << [name, id.to_s, width.to_s, height.to_s]
      end
    end
    send_data(report,
              type: "text/csv",
              charset: "UTF-8",
              header: "present",
              disposition: "attachment",
              filename: "#{action_name}.csv")
  end

  def get_list_of_names(file)
    results = []
    if file.respond_to?(:read) &&
       file.respond_to?(:content_type)
      get_list_of_names_from_file(file)
    elsif file.is_a?(String)
      get_list_of_names_from_string(file)
    elsif file.present?
      raise "Names file came in as an unexpected class:" \
        "#{file.class.name.inspect}"
    else
      raise "Missing names file!"
    end
  end

  def get_list_of_names_from_file(file)
    case file.content_type.chomp
    when "text/plain",
         "application/text",
         "application/octet-stream"
      get_list_of_names_from_plain_text_file(file)
    when "text/csv"
      get_list_of_names_from_csv_file(file)
    else
      raise "Names file has unrecognized content_type: #{content_type.inspect}"
    end
  end

  def get_list_of_names_from_csv_file(file)
    results = CSV.parse(file.read)
    headings = results.shift.map(&:to_s).map(&:downcase)
    name_column = headings.index_of("name")
    rank_column = headings.index_of("rank")
    unless name_column
      raise 'Expected names file to have a \"name\" column, ' \
        "with column label in the first row."
    end
    if rank_column
      results.reject! { |row| row[rank_column].to_s.downcase != "species" }
    end
    results.map do |row|
      row[name_column].to_s.strip_squeeze
    end.reject(:blank?)
  end

  def get_list_of_names_from_plain_text_file(file)
    file.read.split(/[\r\n]+/)
  end

  def get_list_of_names_from_string(str)
    str.split(/\s*,\s*/)
  end

  ##############################################################################

  private

  def whitelisted_image_params
    params.require(:image).permit(whitelisted_image_args)
  end
end
