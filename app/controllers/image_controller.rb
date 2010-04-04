#
#  = Image Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  ==== Searches and Indexes
#  list_images::           . V .
#  images_by_user::        . . .
#  image_search::          . . .
#  advanced_search::       . . .
#  index_image::           . . .
#  show_selected_images::  (helper)
#
#  ==== Show Images
#  show_image::            . V P
#  next_image::            . . .
#  prev_image::            . . .
#  cast_vote::             L . .
#
#  ==== Work With Images
#  add_image::             L V P  Upload images for observation.
#  edit_image::            L V P  Edit notes, etc. for image.
#  destroy_image::         L . .  Callback: destroy image.
#  remove_image::          L . .  Callback: remove image from observation.
#  reuse_image::           L V P  Choose images to add to observation.
#  remove_images::         L V P  Choose images to remove from observation.
#  license_updater::       L V .  Change copyright of many images.
#  process_image::         (helper for add_image)
#
#  ==== Test Actions
#  test_add_image::        L V .
#  test_add_image_report:: L V .
#  test_upload_image::     L . .
#  test_upload_speed::     . V .
#  test_process_image::    (helper for test_upload_image)
#  resize_image::          (helper for test_upload_speed)
#
################################################################################

class ImageController < ApplicationController
  before_filter :login_required, :except => [
    :advanced_search,
    :image_search,
    :images_by_user,
    :index_image,
    :list_images,
    :next_image,
    :prev_image,
    :show_image,
    :test_upload_speed,
  ]

  before_filter :disable_link_prefetching, :except => [
    :add_image,
    :edit_image,
    :remove_images,
    :reuse_image,
    :reuse_image_for_user,
    :show_image,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Display matrix of selected images, based on current Query.
  def index_image
    query = find_or_create_query(:Image, :by => params[:by])
    show_selected_images(query, :id => params[:id], :always_index => true)
  end

  # Display matrix of images, most recent first.
  def list_images
    query = create_query(:Image, :all, :by => :created)
    show_selected_images(query)
  end

  # Display matrix of images by a given user.
  def images_by_user
    user = User.find(params[:id])
    query = create_query(:Image, :by_user, :user => user)
    show_selected_images(query)
  end

  # Display matrix of images whose notes, names, etc. match a string pattern.
  def image_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (image = Image.safe_find(pattern))
      redirect_to(:action => 'show_image', :id => image.id)
    else
      query = create_query(:Image, :pattern_search, :pattern => pattern)
      show_selected_images(query)
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search
    begin
      query = find_query(:Image)
      show_selected_images(query)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search')
    end
  end

  # Show selected search results as a matrix with 'list_images' template.
  def show_selected_images(query, args={})
    store_query_in_session(query)
    @links ||= []

    # I can't figure out why ActiveRecord is not eager-loading all the names.
    # When I do an explicit test (load the first 100 images) it eager-loads
    # about 90%, but for some reason misses 10%, and always the same 10%, but
    # apparently with no rhyme or reason. -JPH 20100204
    args = { :action => 'list_images', :matrix => true,
             :include => [:user, {:observations => :name}] }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',     :sort_by_name.t],
      ['date',     :sort_by_date.t],
      ['user',     :sort_by_user.t],
      # ['copyright_holder', :sort_by_copyright_holder.t],
      ['created',  :sort_by_posted.t],
      ['modified', :sort_by_modified.t],
      ['confidence', :sort_by_confidence.t],
      ['image_quality', :sort_by_image_quality.t],
    ]

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:Observation)
      @links << [:show_objects.t(:type => :observation), {
                  :controller => 'observer',
                  :action => 'index_observation',
                  :params => query_params(query),
                }]
    end

    # Paginate by letter if sorting by user.
    if (query.params[:by] == 'user') or
       (query.params[:by] == 'reverse_user')
      args[:letters] = 'users.login'
    # Paginate by letter if sorting by copyright holder.
    elsif (query.params[:by] == 'copyright_holder') or
          (query.params[:by] == 'reverse_copyright_holder')
      args[:letters] = 'images.copyright_holder'
    # Paginate by letter if names are included in query.
    elsif query.uses_table?(:names)
      args[:letters] = 'names.text_name'
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
  def show_image
    store_location
    @image = Image.find(params[:id],
                        :include => [:user, {:observations => :name}])
    update_view_stats(@image)
    @is_reviewer = is_reviewer
    pass_query_params

    # Decide which size to display.
    @default_size = @user ? @user.image_size : :medium
    @size = params[:size].blank? ? @default_size : params[:size].to_sym

    # Make this size the default image size for this user.
    if @user and (@default_size != @size) and
       (params[:make_default] == '1')
      @user.image_size = @size
      @user.save_without_our_callbacks
      @default_size = @size
    end

    # Update export status.
    if !params[:set_export].blank?
      @image.ok_for_export = (params[:set_export] == '1')
      @image.save_without_our_callbacks
    end

    # Wait until here to create this search query to save server resources.
    # Otherwise we'd be creating a new search query for images for every single
    # show_observation request.  We know we came from an observation-type page
    # because that's the only time the 'obs' param will be set (with obs id).
    obs = params[:obs]
    if !obs.blank? &&
       # The outer search on observation won't be saved for robots, so no sense
       # in bothering with any of this.
       !is_robot?
      obs_query = find_or_create_query(:Observation)
      obs_query.current = obs
      img_query = create_query(:Image, :inside_observation,
                               :observation => obs, :outer => obs_query)
      set_query_params(img_query)
    end
  end

  # Go to next image: redirects to show_image.
  def next_image
    redirect_to_next_object(:next, Image, params[:id])
  end

  # Go to previous image: redirects to show_image.
  def prev_image
    redirect_to_next_object(:prev, Image, params[:id])
  end

  # Change user's vote and go to next image.
  def cast_vote
    image = Image.find(params[:id])
    val = image.change_vote(@user, params[:value])
    Transaction.put_images(:id => image, :set_vote => val)
    if params[:next]
      redirect_to_next_object(:next, Image, params[:id])
    else
      redirect_to(:action => 'show_image', :id => id, :params => query_params)
    end
  end

  ##############################################################################
  #
  #  :section: Work With Images
  #
  ##############################################################################

  # Form for uploading and adding images to an observation.
  # Linked from: show_observation, reuse_image, and
  #   create/edit_naming (via _show_images partial)
  # Inputs: params[:id] (observation)
  #   params[:upload][:image1-4]
  #   params[:image][:copyright_holder]
  #   params[:image][:when]
  #   params[:image][:license_id]
  #   params[:image][:notes]
  # Outputs: @image, @observation
  #   @licenses     (options for license select menu)
  # Redirects to show_observation.
  def add_image
    pass_query_params
    @observation = Observation.find(params[:id])
    if !check_permission!(@observation.user_id)
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
    elsif request.method != :post
      @image = Image.new
      @image.license = @user.license
      @image.copyright_holder = @user.legal_name
      # Set the default date to the date of the observation
      # Don't know how to correctly test this.
      @image.when = @observation.when
      @licenses = License.current_names_and_ids(@image.license)
    else
      args = params[:image]
      process_image(args, params[:upload][:image1])
      process_image(args, params[:upload][:image2])
      process_image(args, params[:upload][:image3])
      process_image(args, params[:upload][:image4])
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
    end
  end

  def process_image(args, upload)
    if !upload.blank?
      name = upload.full_original_filename if upload.respond_to? :full_original_filename
      @image = Image.new(args)
      @image.created  = Time.now
      @image.modified = @image.created
      @image.user     = @user
      @image.image    = upload
      if !@image.save
        flash_object_errors(@image)
      elsif !@image.process_image
        logger.error("Unable to upload image")
        flash_error(:runtime_image_invalid_image.
                      t(:name => (name ? "'#{name}'" : '???')))
        flash_object_errors(@image)
      else
        @observation.add_image(@image)
        @observation.log_create_image(@image)
        Transaction.post_image(
          :id               => @image,
          :url              => @image.original_url,
          :date             => @image.when,
          :notes            => @image.notes,
          :copyright_holder => @image.copyright_holder,
          :license          => @image.license,
          :observation      => @observation
        )
        flash_notice(:runtime_image_uploaded_image.
                       t(:name => name ? "'#{name}'" : "##{@image.id}"))
      end
    end
  end

  # Form for editing date/license/notes on an image.
  # Linked from: show_image/original
  # Inputs: params[:id] (image)
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Outputs: @image, @licenses
  def edit_image
    pass_query_params
    @image = Image.find(params[:id])
    @licenses = License.current_names_and_ids(@image.license)
    if !check_permission!(@image.user_id)
      redirect_to(:action => 'show_image', :id => @image,
                  :params => query_params)
    elsif request.method == :post
      @image.attributes = params[:image]
      xargs = {}
      xargs[:set_date]             = @image.when             if @image.when_changed?
      xargs[:set_notes]            = @image.notes            if @image.notes_changed?
      xargs[:set_copyright_holder] = @image.copyright_holder if @image.copyright_holder_changed?
      xargs[:set_license]          = @image.license          if @image.license_id_changed?
      if xargs.empty?
        flash_notice(:runtime_no_changes.t)
      elsif !@image.save
        flash_object_errors(@image)
      else
        xargs[:id] = @image
        Transaction.put_image(xargs)
        @image.log_update
        flash_notice :runtime_image_edit_success.t(:id => @image.id)
        redirect_to(:action => 'show_image', :id => @image.id,
                    :params => query_params)
      end
    end
  end

  # Callback to destroy an image.
  # Linked from: show_image/original
  # Inputs: params[:id] (image)
  # Redirects to list_images.
  def destroy_image

    # All of this just to decide where to redirect after deleting image.
    @image = Image.find(params[:id])
    next_state = nil
    if this_state = find_query(:Image)
      set_query_params(this_state)
      this_state.current = @image
      next_state = this_state.next
    end

    if !check_permission!(@image.user_id)
      redirect_to(:action => 'show_image', :id => @image.id,
                  :params => query_params)
    else
      @image.log_destroy
      @image.destroy
      Transaction.delete_image(:id => @image)
      flash_notice(:runtime_image_destroy_success.t(:id => params[:id]))
      if next_state
        redirect_to(:action => 'show_image', :id => next_state.current_id,
                    :params => set_query_params(next_state))
      else
        redirect_to(:action => 'list_images')
      end
    end
  end

  # Callback to remove a single image from an observation.
  # Linked from: observer/edit_observation
  # Inputs: params[:image_id], params[:observation_id]
  # Redirects to show_observation.
  def remove_image
    pass_query_params
    @image = Image.find(params[:image_id])
    @observation = Observation.find(params[:observation_id])
    if !check_permission!(@observation.user_id)
      flash_error(:runtime_image_remove_denied.t(:id => @image.id))
    elsif !@observation.images.include?(@image)
      flash_error(:runtime_image_remove_missing.t(:id => @image.id))
    else
      @observation.remove_image(@image)
      @observation.log_remove_image(@image)
      Transaction.put_observation(
        :id        => @observation,
        :del_image => @image
      )
      flash_notice(:runtime_image_remove_success.t(:id => @image.id))
    end
    redirect_to(:controller => 'observer', :action => 'show_observation',
                :id => @observation.id, :params => query_params)
  end

  # Browse through matrix of recent images to let a user reuse an image
  # they've already uploaded for another observation.
  # Linked from: observer/show_observation and account/profile
  # Inputs:
  #   params[:mode]       'observation' or 'profile'
  #   params[:obs_id]     (observation)
  #   params[:img_id]     (image)
  #   params[:all_users]  '0' or '1'
  # Outputs:
  #   @mode           :observation or :profile
  #   @all_users      true or false
  #   @pages          paginator for images
  #   @objects        Array of images
  #   @observation    observation (if in observation mode)
  #   @layout         layout parameters
  # Posts to the same action.  Redirects to show_observation or show_user.
  def reuse_image
    pass_query_params
    @mode = params[:mode].to_sym
    @observation = Observation.find(params[:obs_id]) if @mode == :observation
    done = false

    # Make sure user owns the observation.
    if (@mode == :observation) and
       !check_permission!(@observation.user_id)
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
      done = true

    # User entered an image id by hand or clicked on an image.
    elsif (request.method == :post) or
          !params[:img_id].blank?
      image = Image.safe_find(params[:img_id])
      if !image
        flash_error(:runtime_image_reuse_invalid_id.t(:id => params[:img_id]))

      # Add image to observation.
      elsif @mode == :observation
        @observation.add_image(image)
        @observation.log_reuse_image(image)
        Transaction.put_observation(:id => @observation, :add_image => image)
        redirect_to(:controller => 'observer', :action => 'show_observation',
                    :id => @observation.id, :params => query_params)
        done = true

      # Change user's profile image.
      else
        if @user.image == image
          flash_notice(:runtime_no_changes.t)
        else
          @user.update_attributes(:image => image)
          Transaction.put_user(:id => @user, :set_image => image)
          flash_notice(:runtime_image_changed_your_image.t(:id => image.id))
        end
        redirect_to(:controller => "observer", :action => "show_user",
                    :id => @user.id)
        done = true
      end
    end

    # Serve form.
    if !done
      if params[:all_users] == '1'
        @all_users = true
        query = create_query(:Image, :all, :by => :modified)
      else
        query = create_query(:Image, :by_user, :user => @user, :by => :modified)
      end
      @layout = calc_layout_params
      @pages = paginate_numbers(:page, @layout['count'])
      @objects = query.paginate(@pages,
                                :include => [:user, {:observations => :name}])
    end
  end

  # Form used to remove one or more images from an observation (not destroy!)
  # Linked from: show_observation
  # Inputs:
  #   params[:id]                  (observation)
  #   params[:selected][image_id]  (value of "yes" means delete)
  # Outputs: @observation
  # Redirects to show_observation.
  def remove_images
    pass_query_params
    @observation = Observation.find(params[:id], :include => :images)

    # Make sure user owns the observation.
    if !check_permission!(@observation.user_id)
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)

    # POST -- remove selected images.
    elsif request.method == :post
      if images = params[:selected]
        images.each do |image_id, do_it|
          if do_it == 'yes'
            if image = Image.find(image_id)
              @observation.remove_image(image)
              @observation.log_remove_image(image)
              flash_notice(:runtime_image_remove_success.t(:id => image_id))
            end
          end
        end
      end
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
    end
  end

  # Tabular form that lets user change licenses of their images.  The table
  # groups all the images of a given copyright holder and license type into
  # a single row.  This lets you change all of Rolf's licenses in one stroke.
  # Linked from: account/prefs
  # Inputs:
  #   params[:updates][license_id][copyright_holder]   (new license_id)
  # Outputs: @data
  #   @data[n]['copyright_holder']  Person who actually holds copyright.
  #   @data[n]['license_count']     Number of images this guy holds with this type of license.
  #   @data[n]['selected']          ID of current license.
  #   @data[n]['license_id']        ID of current license.
  #   @data[n]['license_name']      Name of current license.
  #   @data[n]['select_id']         ID of HTML select menu element.
  #   @data[n]['select_name']       Name of HTML select menu element.
  #   @data[n]['licenses']          Options for select menu.
  def license_updater

    # Process any changes.
    if request.method == :post
      for current_id, value in params[:updates]
        current_id = current_id.to_i
        current_license = License.find(current_id)
        for copyright_holder, new_id in value
          new_id = new_id.to_i
          new_license = License.find(new_id)
          if current_id != new_id
            Image.connection.update %(
              UPDATE images SET license_id = #{new_id}
              WHERE copyright_holder = #{Image.connection.quote(copyright_holder.to_s)}
                AND license_id = #{current_id} AND user_id = #{@user.id}
            )
            Transaction.put_image(
              :copyright_holder => copyright_holder,
              :license          => current_license,
              :user             => @user,
              :set_license      => new_license
            )
          end
        end
      end
    end

    # Gather data for form.
    id = @user.id.to_i # Make sure it's an integer
    query = "select count(*) as license_count, copyright_holder, license_id
      from images where user_id = #{id} group by copyright_holder, license_id"
    @data = Image.connection.select_all(query)
    for datum in @data
      license = License.find(datum['license_id'])
      datum['license_name'] = license.display_name
      datum['select_id']    = "updates_#{datum['license_id']}_#{datum['copyright_holder']}".gsub!(/\W/, '_')
      datum['select_name']  = "updates[#{datum['license_id']}][#{datum['copyright_holder']}]"
      datum['licenses']     = License.current_names_and_ids(license)
      datum['selected']     = license.id
    end
  end

  ##############################################################################
  #
  #  :section: Test Actions
  #
  ##############################################################################

  def test_upload_speed
    logger.warn(params)
    image_stream = params[:file]
    data = image_stream.read
    original = TEST_IMG_DIR + "/orig/upload_speed_test.jpg"
    big = TEST_IMG_DIR + "/640/upload_speed_test.jpg"
    thumbnail = TEST_IMG_DIR + "/thumb/upload_speed_test.jpg"
    file = File.new(original, 'w')
    file.print(data)
    file.close
    self.resize_image(640, 640, 70, original, big)
    self.resize_image(160, 160, 90, big, thumbnail)
  end

  # Resize +src+ image and save as +dest+, stripping headers.
  def resize_image(width, height, quality, src, dest)
    if File.exists?(src)
      cmd = sprintf("convert -thumbnail '%dx%d>' -quality %d %s %s",
                     width, height, quality, src, dest)
      system cmd
      logger.warn(cmd)
    end
  end

  def test_process_image(user, upload, count, size)
    if !upload.blank?
      @image = Image.new(
        :user  => user,
        :image => upload
      )
      @image.id = user.id
      @image.image_dir = TEST_IMG_DIR
      @image.process_image
      count += 1
      size += File.new(@image.original_image).stat.size
    end
    [count, size]
  end

  def test_upload_image
    @log_entry = AddImageTestLog.find(params[:log_id])
    @log_entry.upload_start = Time.now
    @log_entry.save # Record that upload started
    @log_entry.upload_data_start = Time.now # Just in case save takes a long time
    count, size = test_process_image(@user, params[:upload][:image1], 0, 0)
    count, size = test_process_image(@user, params[:upload][:image2], count, size)
    count, size = test_process_image(@user, params[:upload][:image3], count, size)
    count, size = test_process_image(@user, params[:upload][:image4], count, size)
    @log_entry.upload_end = Time.now
    @log_entry.image_count = count
    @log_entry.image_bytes = size
    @log_entry.save
    redirect_to(:action => 'test_add_image_report')
  end

  def test_add_image
    @log_entry = AddImageTestLog.new
    @log_entry.user = @user
    @log_entry.save
    @upload = {}
  end

  def test_add_image_report
    @log_entries = AddImageTestLog.find(:all, :order => 'created desc')
  end
end
