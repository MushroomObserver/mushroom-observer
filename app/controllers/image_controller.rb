#
#  Views: ("*" - login required, "R" - root required))
#     index_image         Display matrix of images for current query.
#     list_images         Display matrix of images, sorted by date.
#     images_by_user      Display list of images by a given user.
#     image_search        Search for matching images.
#     show_image          Show in standard size (640 pixels max dimension).
#     show_original       Show original size.
#     prev_image          Show previous image (from search results).
#     next_image          Show next image (from search results).
#   * add_image           Upload and add images to observation.
#   * remove_images       Remove image(s) from an observation (not destroy!)
#   * edit_image          Edit date, copyright, notes.
#   * destroy_image       Destroy image.
#   * remove_image        Remove an image from an observation.
#   * reuse_image         Add an already-uploaded image to an observation.
#   * add_image_to_obs    (post method #1 for reuse_image)
#   * reuse_image_by_id   (post method #2 for reuse_image)
#   * reuse_image_for_user Select an already-uploaded image to user profile.
#   * license_updater     Bulk license editor.
#
#  Admin Tools:
#   R resize_images      Re-create all thumbnails.
#
#  Test Views:
#     test_upload_image
#     test_add_image
#     test_add_image_report
#     test_process_image(user, upload, count, size)
#
#  Helpers:
#    process_image(args, upload)
#    show_selected_images(title, conditions, order, source)
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
    :show_original,
    :test_upload_speed,
  ]

  before_filter :disable_link_prefetching, :except => [
    :add_image,
    :edit_image,
    :next_image,
    :prev_image,
    :remove_image,
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
    query = find_or_create_query(:Image, :all, :by => params[:by] || :created)
    query.params[:by] = params[:by] if params[:by]
    show_selected_images(query, :id => params[:id])
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
      query = create_query(:Image, :pattern, :pattern => pattern)
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
      flash_error(err.backtrace.join("<br/>"))
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
      ['name', :name.t], 
      ['date', :DATE.t],
      ['user', :user.t],
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

    # Paginate by letter as well as page if names are included in query.
    if query.uses_table?(:names)
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

    # Wait until here to create this search query to save server resources.
    # Otherwise we'd be creating a new search query for images for every single
    # show_observation request.  We know we came from an observation-type page
    # because that's the only time the 'obs' param will be set (with obs id).
    obs = params[:obs]
    if obs.to_s != '' &&
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

  # Show the original size image.
  # Linked from: show_image
  # Inputs: params[:id] (image)
  # Outputs: @image
  def show_original
    store_location
    pass_query_params
    @image = Image.find(params[:id])
  end

  # Go to next image: redirects to show_image.
  def next_image
    redirect_to_next_object(:next, Image, params[:id])
  end

  # Go to previous image: redirects to show_image.
  def prev_image
    redirect_to_next_object(:prev, Image, params[:id])
  end

  def set_image_quality
    id = params[:id]
    if is_reviewer
      image = Image.find(id)
      image.quality = params[:value]
      image.reviewer_id = @user.id
      image.save
    end
    redirect_to(:action => (params[:next]) ? 'next_image' : 'show_image', :id => id,
                :params => query_params)
  end

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
    if upload and upload != ""
      name = upload.full_original_filename if upload.respond_to? :full_original_filename
      @image = Image.new(args)
      @image.created  = Time.now
      @image.modified = @image.created
      @image.user     = @user
      @image.image    = upload
      if !@image.save
        flash_object_errors(@image)
      elsif !@image.save_image
        logger.error("Unable to upload image")
        flash_error :profile_invalid_image. \
          t(:name => (name ? "'#{name}'" : '???'))
        flash_object_errors(@image)
      else
        Transaction.post_image(
          :id               => @image,
          :url              => @image.original_url,
          :date             => @image.when,
          :notes            => @image.notes,
          :copyright_holder => @image.copyright_holder,
          :license          => @image.license
        )
        @observation.add_image_with_log(@image, @user)
        flash_notice :profile_uploaded_image.
                          t(:name => name ? "'#{name}'" : "##{@image.id}")
      end
    end
  end

  # Form used to remove one or more images from an observation (not destroy!)
  # Linked from: show_observation, create/edit_naming (via _show_images partial)
  # Inputs: params[:id] (observation)
  #   params[:observation][:id]
  #   params[:selected][image_id]       (value of "yes" means delete)
  # Outputs: @observation
  # Redirects to show_observation.
  def remove_images
    pass_query_params
    @observation = Observation.find(params[:id], :include => :images)
    if !check_permission!(@observation.user_id)
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
    elsif request.method != :post
      # @image = Image.new
      # @image.copyright_holder = @user.legal_name
    else
      # Delete images
      images = params[:selected]
      if images
        images.each do |image_id, do_it|
          if do_it == 'yes'
            if image = @observation.remove_image_by_id(image_id)
              @observation.log(:log_image_removed,
                        :name => image.unique_format_name, :touch => false)
              flash_notice :runtime_image_remove_success.t(:id => image_id)
            end
          end
        end
      end
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
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
      if !@image.update_attributes(params[:image])
        args = {}
        args[:date]             = @image.when             if @image.when_changed?
        args[:notes]            = @image.notes            if @image.notes_changed?
        args[:copyright_holder] = @image.copyright_holder if @image.copyright_holder_changed?
        args[:license]          = @image.license          if @image.license_id_changed?
        if !args.empty?
          args[:id] = @image
          Transaction.put_image(args)
        end
        flash_object_errors(@image)
      else
        for o in @image.observations
          o.log(:log_image_updated, :name => @image.unique_format_name)
        end
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
    elsif !@image.destroy
      flash_error :runtime_image_destroy_failed.t(:id => @image.id)
      redirect_to(:action => 'show_image', :id => @image.id,
                  :params => query_params)
    else
      Transaction.delete_image(:id => @image)
      flash_notice :runtime_image_destroy_success.t(:id => params[:id])
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
      flash_warning :runtime_image_remove_denied.t(:id => @image.id)
    elsif !@observation.images.include?(@image)
      flash_warning :runtime_image_remove_missing.t(:id => @image.id)
    else
      @observation.images.delete(@image)
      @observation.log(:log_image_removed, :name => @image.unique_format_name,
                       :touch => false)
      if @observation.thumb_image_id == @image.id
        @observation.thumb_image_id = nil
        @observation.save
      end
      Transaction.put_observation(
        :id        => @observation,
        :del_image => @image
      )
      flash_notice :runtime_image_remove_success.t(:id => @image.id)
    end
    redirect_to(:controller => 'observer', :action => 'show_observation',
                :id => @observation.id, :params => query_params)
  end

  # Browse through matrix of recent images to let a user reuse an image
  # they've already uploaded for another observation.
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Outputs: @images, @image_pages, @observation, @layout
  # (See also add_image_to_obs and reuse_image_by_id.)
  def reuse_image
    pass_query_params
    @observation = Observation.find(params[:id])
    @layout = calc_layout_params
    if !check_permission!(@observation.user_id)
      redirect_to(:controller => 'observer', :action => 'show_observation',
                  :id => @observation.id, :params => query_params)
    elsif params[:all_users] == '1'
      @all_users = true
      query = create_query(:Image, :all, :by => :modified)
      @pages = paginate_numbers(:page, @layout['count'])
      @objects = query.paginate(@pages,
                                :include => [:user, {:observations => :name}])
    else
      query = create_query(:Image, :by_user, :user => @user)
      query.order = 'users.modified DESC'
      @pages = paginate_numbers(:page, @layout['count'])
      @objects = query.paginate(@pages,
                                :include => [:user, {:observations => :name}])
    end
  end

  # First post method for reuse_image: user has clicked on one of the images.
  # Add this image to the new observation.
  # Inputs:
  #   params[:id]       (image)
  #   params[:obs_id]   (observation)
  # Redirects to show_observation.
  def add_image_to_obs
    pass_query_params
    @observation = Observation.find(params[:obs_id])
    if check_permission!(@observation.user_id)
      if image = @observation.add_image_by_id(params[:id])
        @observation.log(:log_image_reused, :name => image.unique_format_name)
        flash_notice :runtime_image_reuse_success.t(:id => image.id)
      end
    end
    redirect_to(:controller => 'observer', :action => 'show_observation',
                :id => @observation.id, :params => query_params)
  end

  # Second post method for reuse_image: user has entered an image id in the
  # text field.  Add this image (assuming it exists!) to the new observation.
  # Inputs:
  #   params[:observation][:id]     (observation)
  #   params[:observation][:idstr]  (image)
  # Redirects to show_observation.
  def reuse_image_by_id
    pass_query_params
    @observation = Observation.find(params[:observation][:id])
    if check_permission!(@observation.user_id)
      if image = @observation.add_image_by_id(params[:observation][:idstr].to_i)
        @observation.log(:log_image_reused, :name => image.unique_format_name)
        flash_notice :runtime_image_reuse_success.t(:id => image.id)
      end
    end
    redirect_to(:controller => 'observer', :action => 'show_observation',
                :id => @observation.id, :params => query_params)
  end

  # Browse through matrix of recent images to let a user reuse an image
  # they've already uploaded for their profile.  This method does get and post.
  # Linked from: account/prefs
  # Inputs: none
  # Outputs: @images, @image_pages, @layout
  def reuse_image_for_user
    # Will return here either by typing in id and posting form, or by
    # clicking on an image (in which case method is "get").
    if request.method == "post" || params[:id]
      begin
        image = Image.find(params[:id])
        if @user.image != image
          @user.image = image
          @user.save
          Transaction.put_user(
            :id        => @user,
            :set_image => image
          )
        end
        flash_notice :runtime_image_changed_your_image.t(:id => image.id)
        redirect_to(:controller => "observer", :action => "show_user",
                    :id => @user.id)
        redirected = true
      rescue(e)
        flash_error :runtime_image_reuse_invalid_id.t(:id => params[:id])
      end
    end
    if !redirected
      @layout = calc_layout_params
      if params[:all_users] == '1'
        @all_users = true
        query = create_query(:Image, :all, :by => :modified)
        @pages = paginate_numbers(:page, @layout['count'])
        @objects = query.paginate(@pages,
                                :include => [:user, {:observations => :name}])
      else
        query = create_query(:Image, :by_user, :user => @user)
        query.order = 'users.modified DESC'
        @pages = paginate_numbers(:page, @layout['count'])
        @objects = query.paginate(@pages,
                                :include => [:user, {:observations => :name}])
      end
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
              WHERE copyright_holder = "#{copyright_holder.gsub('"','\\"').gsub('\\','\\\\')}"
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

################################################################################

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

################################################################################

  def test_process_image(user, upload, count, size)
    if upload and upload != ""
      args = {
        :user => user,
        :image => upload
      }
      @image = Image.new(args)
      @image.id = user.id
      @image.img_dir = TEST_IMG_DIR
      @image.save_image
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

################################################################################

  def resize_images
    if is_in_admin_mode?
      for image in Image.find(:all)
        image.calc_size()
        image.resize_image(160, 160, image.thumbnail)
      end
    else
      flash_error :runtime_image_resize_denied.t
    end
    redirect_to(:action => 'list_images')
  end
end
