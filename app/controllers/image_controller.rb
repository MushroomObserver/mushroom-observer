#
#  Views: ("*" - login required, "R" - root required))
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
#    calc_image_ids(obs)
#    next_id(id, id_list)
#    prev_id(id, id_list)
#    next_image_list(observation_id, id_list)
#    prev_image_list(observation_id, id_list)
#    show_selected_images(title, conditions, order, source)
#    inc_image_from_obs_search(state, inc_func, direction)
#    inc_image(func_name, direction)
#
################################################################################

class ImageController < ApplicationController
  before_filter :login_required, :except => [
    :advanced_obj_search,
    :list_images,
    :images_by_user,
    :image_search,
    :show_image,
    :show_original,
    :next_image,
    :prev_image,
    :test_upload_speed
  ]

  # Display matrix of images, most recent first.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs: @objs, @obj_pages, @layout
  def list_images
    session[:checklist_source] = :nothing
    session_setup
    store_location
    @layout = calc_layout_params
    @obj_pages, @objs = paginate(:images, :order => "modified desc", :per_page => @layout["count"])
  end

  # Display list of images by a given user.
  # Linked from observer/show_user
  # Inputs: params[:id] (user)
  # Outputs: @images
  def images_by_user
    user = User.find(params[:id])
    session[:checklist_source] = :nothing
    session_setup
    store_location
    @layout = calc_layout_params
    @title = :images_by_user.t(:user => user.legal_name)
    @obj_pages, @objs = paginate(:images, :order => "modified desc",
      :conditions => "user_id = #{user.id}", :per_page => @layout["count"])
    render(:action => "list_images")
  end

  # Searches image notes, copyright, and consensus name (including author)
  # for all observations it's associated with.
  # Redirected from: pattern_search (search bar)
  # Inputs:
  #   session[:pattern]
  # Outputs:
  #   Renders list_images.
  def image_search
    store_location
    @layout = calc_layout_params
    @pattern = params[:pattern] || session[:pattern] || ''
    id = @pattern.to_i
    image = nil
    if @pattern == id.to_s
      begin
        image = Image.find(id)
      rescue ActiveRecord::RecordNotFound
      end
    end
    if image
      redirect_to(:action => 'show_image', :id => id)
    else
      show_selected_images(:image_search_title.t(:pattern => @pattern),
        field_search(["n.search_name", "i.notes", "i.copyright_holder"], "%#{@pattern.gsub(/[*']/,"%")}%"),
        "n.search_name, `when` desc", :nothing)
    end
  end

  def advanced_obj_search
    begin
      @layout = calc_layout_params
      query = calc_advanced_search_query("SELECT STRAIGHT_JOIN DISTINCT images.* FROM",
        Set.new(['observations', 'images_observations', 'images']), params)
      show_selected_objs("Advanced Search", query, nil, :nothing, :advanced_images, 'list_images', nil)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search')
    end
  end

  def show_selected_images(title, conditions, order, source)
    # If provided, link should be the arguments for link_to as a list of lists,
    # e.g. [[:action => 'blah'], [:action => 'blah']]
    show_selected_objs(title, conditions, order, source, :images, 'list_images')
  end

  # Show the 640x640 (max size) version of image.
  # Linked from: thumbnails, next/prev_image, etc.
  # Inputs: params[:id] (image)
  # Outputs: @image
  def show_image
    store_location
    pass_seq_params()
    @image = Image.find(params[:id])
    update_view_stats(@image)
    @is_reviewer = is_reviewer
  end

  # Show the original size image.
  # Linked from: show_image
  # Inputs: params[:id] (image)
  # Outputs: @image
  def show_original
    store_location
    pass_seq_params()
    @image = Image.find(params[:id])
  end

  def inc_image_from_obs_search(state, inc_func, direction)
    current_image_id = params[:id].to_i
    current_image = Image.find(current_image_id)
    new_image = nil
    current_observation_id = state.current_id
    current_observation = Observation.find(current_observation_id)
    if current_image && current_observation
      images = current_observation.images
      index = (direction == 1) ? images.rindex(current_image) : images.index(current_image)
      if index
        index += direction
        if 0 <= index && index < images.length # Have to check explicitly since foo[-1] is the not nil
          new_image = images[index]
        end
      end
      if new_image.nil?
        inc_func.call
        count = Observation.count
        while current_observation_id != state.current_id
          current_observation_id = state.current_id
          current_observation = Observation.find(current_observation_id)
          if current_observation
            if direction == -1
              new_image = current_observation.images[-1] # Start from the last image
            else
              new_image = current_observation.images[0]
            end
            count -= 1
            if new_image.nil? and count > 0
              inc_func.call()
            end
          end
        end
      end
    end
    if new_image.nil?
      flash_warning(:image_no_new_image.t)
      new_image = current_image
    end
    state.save if !is_robot?
    redirect_to(:action => 'show_image', :id => new_image, :seq_key => state.id)
  end

  def inc_image(func_name, direction) # direction is 1 or -1 depending on if we're doing next or prev
    state = SequenceState.lookup(params, :images, logger)
    inc_func = state.method(func_name)
    pass_seq_params()
    case state.query_type
    when :images
      inc_func.call()
      state.save if !is_robot?
      id = state.current_id
      if id
        redirect_to(:action => 'show_image', :id => id, :seq_key => state.id)
      else
        redirect_to(:controller => 'observer', :action => 'list_rss_logs')
      end
    when :observations
      # Need to walk through images for current observation, then walk through the remaining observations
      inc_image_from_obs_search(state, inc_func, direction)
    when :rss_logs
      inc_image_from_obs_search(state, inc_func, direction)
    when :name_observations
      inc_image_from_obs_search(state, inc_func, direction)
    else
      redirect_to(:controller => 'observer', :action => 'list_rss_logs')
    end
  end

  def next_image
    inc_image("next", 1)
  end

  def prev_image
    inc_image("prev", -1)
  end

  def set_image_quality
    id = params[:id]
    if is_reviewer
      image = Image.find(id)
      image.quality = params[:value]
      image.reviewer_id = session[:user_id]
      image.save
    end
    redirect_to(:action => (params[:next]) ? 'next_image' : 'show_image', :id => id,
                :seq_key => params[:seq_key], :search_seq => params[:search_seq], :obs => params[:obs])
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
    @observation = Observation.find(params[:id])
    if !check_user_id(@observation.user_id)
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
    elsif request.method == :get
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
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
    end
  end

  def process_image(args, upload)
    if upload and upload != ""
      name = upload.full_original_filename if upload.respond_to? :full_original_filename
      args[:image] = upload
      @image = Image.new(args)
      @image.created = Time.now
      @image.modified = @image.created
      @image.user = @user
      if !@image.save
        flash_object_errors(@image)
      elsif !@image.save_image
        logger.error("Unable to upload image")
        flash_error :profile_invalid_image. \
          t(:name => (name ? "'#{name}'" : '???'))
        flash_object_errors(@image)
      else
        @observation.add_image_with_log(@image, @user)
        flash_notice :profile_uploaded_image. \
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
    @observation = Observation.find(params[:id])
    if verify_user()
      if !check_user_id(@observation.user_id)
        redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
      elsif request.method == :get
        # @image = Image.new
        # @image.copyright_holder = @user.legal_name
      else
        # Delete images
        images = params[:selected]
        if images
          images.each do |image_id, do_it|
            if do_it == 'yes'
              image = @observation.remove_image_by_id(image_id)
              if !image.nil?
                @observation.log(:log_image_removed, { :user => @user.login,
                  :name => image.unique_format_name }, false)
                flash_notice :image_remove_success.t(:id => image_id)
              end
            end
          end
        end
        redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
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
    @image = Image.find(params[:id])
    @licenses = License.current_names_and_ids(@image.license)
    if verify_user()
      if !check_user_id(@image.user_id)
        redirect_to(:action => 'show_image', :id => @image)
      elsif request.method == :post
        @image.attributes = params[:image]
        @image.modified = Time.now
        if !@image.save
          flash_object_errors(@image)
        else
          for o in @image.observations
            o.log(:log_image_updated, { :user => @user.login,
              :name => @image.unique_format_name }, true)
          end
          flash_notice :image_edit_success.t
          redirect_to(:action => 'show_image', :id => @image.id)
        end
      end
    end
  end

  # Callback to destroy an image.
  # Should this be allowed?  How do we cleanup corresponding observations?
  # Linked from: show_image/original
  # Inputs: params[:id] (image)
  # Redirects to list_images.
  def destroy_image
    @image = Image.find(params[:id])
    if verify_user()
      if !check_user_id(@image.user_id)
        redirect_to(:action => 'show_image', :id => @image.id)
      elsif !@image.destroy(@user)
        flash_error :image_destroy_failed.t
        redirect_to(:action => 'show_image', :id => @image.id)
      else
        flash_notice :image_destroy_success.t
        redirect_to(:action => 'list_images')
      end
    end
  end

  # Callback to remove a single image from an observation.
  # Linked from: observer/edit_observation
  # Inputs: params[:image_id], params[:observation_id]
  # Redirects to show_observation.
  def remove_image
    @image = Image.find(params[:image_id])
    @observation = Observation.find(params[:observation_id])
    if verify_user()
      if !check_user_id(@observation.user_id)
        flash_warning :image_remove_denied.t
      elsif !@observation.images.include?(@image)
        flash_warning :image_remove_missing.t
      else
        @observation.images.delete(@image)
        @observation.log(:log_image_removed, { :user => @user.login,
          :name => @image.unique_format_name }, false)
        if @observation.thumb_image_id == @image.id
          @observation.thumb_image_id = nil
          @observation.save
        end
        flash_notice :image_remove_success.t(:id => @image.id)
      end
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
    end
  end

  # Browse through matrix of recent images to let a user reuse an image
  # they've already uploaded for another observation.
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Outputs: @images, @image_pages, @observation, @layout
  # (See also add_image_to_obs and reuse_image_by_id.)
  def reuse_image
    @observation = Observation.find(params[:id])
    @layout = calc_layout_params
    if verify_user()
      if !check_user_id(@observation.user_id)
        redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
      elsif params[:all_users] == '1'
        @all_users = true
        @image_pages, @images = paginate(:images,
                                         :order => "modified desc",
                                         :per_page => @layout["count"])
      else
        @image_pages, @images = paginate(:images,
                                         :conditions => ['user_id = ?', @user.id],
                                         :order => "modified desc",
                                         :per_page => @layout["count"])
      end
    end
  end

  # First post method for reuse_image: user has clicked on one of the images.
  # Add this image to the new observation.
  # Inputs:
  #   params[:id]       (image)
  #   params[:obs_id]   (observation)
  # Redirects to show_observation.
  def add_image_to_obs
    @observation = Observation.find(params[:obs_id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:id])
      if !image.nil?
        @observation.log(:log_image_reused, { :user => @user.login,
          :name => image.unique_format_name }, true)
        flash_notice :image_reuse_success.t(:id => image.id)
      end
    end
    redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
  end

  # Second post method for reuse_image: user has entered an image id in the
  # text field.  Add this image (assuming it exists!) to the new observation.
  # Inputs:
  #   params[:observation][:id]     (observation)
  #   params[:observation][:idstr]  (image)
  # Redirects to show_observation.
  def reuse_image_by_id
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:observation][:idstr].to_i)
      if !image.nil?
        @observation.log(:log_image_reused, { :user => @user.login,
          :name => image.unique_format_name }, true)
        flash_notice :image_reuse_success.t(:id => image.id)
      end
    end
    redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation.id)
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
        @user.image = image
        @user.save
        flash_notice :image_changed_your_image.t(:id => image.id)
        redirect_to(:controller => "observer", :action => "show_user", :id => @user.id)
        redirected = true
      rescue(e)
        flash_error :image_reuse_invalid_id.t
      end
    end
    if !redirected
      @layout = calc_layout_params
      if params[:all_users] == '1'
        @all_users = true
        @image_pages, @images = paginate(:images,
                                         :order => "modified desc",
                                         :per_page => @layout["count"])
      else
        @image_pages, @images = paginate(:images,
                                         :conditions => ['user_id = ?', @user.id],
                                         :order => "modified desc",
                                         :per_page => @layout["count"])
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
    if verify_user()
      #
      # Process any changes.
      if request.method == :post
        for current_id, value in params[:updates]
          current_id = current_id.to_i
          for copyright_holder, new_id in value
            new_id = new_id.to_i
            if current_id != new_id
              Image.connection.update %(
                UPDATE images SET license_id = #{new_id}
                WHERE copyright_holder = "#{copyright_holder.gsub('"','\\"')}"
                  AND license_id = #{current_id} AND user_id = #{@user.id}
              )
            end
          end
        end
      end
      #
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
    if verify_user()
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
  end

  def test_add_image
    if verify_user()
      @log_entry = AddImageTestLog.new
      @log_entry.user = @user
      @log_entry.save
      @upload = {}
    end
  end

  def test_add_image_report
    if verify_user()
      @log_entries = AddImageTestLog.find(:all, :order => 'created_at desc')
    end
  end

################################################################################

  def resize_images
    if check_permission(0)
      for image in Image.find(:all)
        image.calc_size()
        image.resize_image(160, 160, image.thumbnail)
      end
    else
      flash_error :image_resize_denied.t
    end
    redirect_to(:action => 'list_images')
  end

################################################################################

  helper_method :next_id
  def next_id(id, id_list)
    result = id
    if id_list.length > 0
      result = id_list[0]
      index = id_list.index(id)
      if index
        index = index + 1
        if index < id_list.length
          result = id_list[index]
        end
      end
    end
    result
  end

  helper_method :next_image_list
  def next_image_list(observation_id, id_list)
    image_list = []
    current_id = observation_id
    if id_list.length > 0
      index = id_list.index(observation_id)
      if index.nil?
        index = id_list.length - 1
        observation_id = id_list[index]
      end
      current_id = observation_id
      while image_list == []
        current_id = next_id(current_id, id_list)
        if current_id == observation_id
          break
        end
        images = Observation.find(current_id).images
        image_list = []
        for i in images
          image_list.push(i.id)
        end
      end
    end
    [image_list, current_id]
  end

  helper_method :prev_id
  def prev_id(id, id_list)
    result = id
    if id_list.length > 0
      result = id_list[-1]
      index = id_list.index(id)
      if index
        index = index - 1
        if index >= 0
          result = id_list[index]
        end
      end
    end
    result
  end

  helper_method :prev_image_list
  def prev_image_list(observation_id, id_list)
    image_list = []
    current_id = observation_id
    if id_list.length > 0
      index = id_list.index(observation_id)
      if index.nil?
        index = 0
        observation_id = id_list[index]
      end
      current_id = observation_id
      while image_list == []
        current_id = prev_id(current_id, id_list)
        if current_id == observation_id
          break
        end
        images = Observation.find(current_id).images
        image_list = []
        for i in images
          image_list.push(i.id)
        end
      end
    end
    [image_list, current_id]
  end

  helper_method :calc_image_ids
  def calc_image_ids(obs)
    result = nil
    if obs
      result = []
      for ob_id in obs:
        img_ids = Observation.connection.select_all("select image_id
          from images_observations where observation_id=" + ob_id.to_s)
        for h in img_ids
          result.push(h['image_id'].to_i)
        end
      end
    end
    result
  end
end
