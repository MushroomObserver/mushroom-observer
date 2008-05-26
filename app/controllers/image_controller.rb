# Copyright (c) 2008 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

################################################################################
#
#  Views:
#    list_images         Display matrix of images, sorted by date.
#    images_by_title     Display list of images, sorted by title.
#    show_image          Show in standard size (640 pixels max dimension).
#    show_original       Show original size.
#    prev_image          Show previous image (from search results).
#    next_image          Show next image (from search results).
#    add_image           Upload and add images to observation.
#    remove_images       Remove image(s) from an observation (not destroy!)
#    edit_image          Edit date, copyright, notes.
#    destroy_image       Destroy image.
#    reuse_image         Add an already-uploaded image to an observation.
#    add_image_to_obs    (post method #1 for reuse_image)
#    reuse_image_by_id   (post method #2 for reuse_image)
#    license_updater     Bulk license editor.
#
#  Admin Tools:
#    resize_images      Re-create all thumbnails.
#
#  Test Views:
#    test_upload_image
#    test_add_image
#    test_add_image_report
#    test_process_image(user, upload, count, size)
#
#  Helpers:
#    process_image(args, upload)
#    current_image_state
#    next_id(id, id_list)
#    prev_id(id, id_list)
#    next_image_list(observation_id, id_list)
#    prev_image_list(observation_id, id_list)
#    calc_image_ids(obs)
#
################################################################################

class ImageController < ApplicationController
  before_filter :login_required, :except => [
    :list_images,
    :images_by_title,
    :image_search,
    :show_image,
    :show_original,
    :next_image,
    :prev_image
  ]

  # Display matrix of images, most recent first.
  # Linked from: left-hand panel
  # Inputs: session['user']
  # Outputs: @objs, @obj_pages, @user, @layout
  def list_images
    session[:checklist_source] = :nothing
    session[:observation_ids] = []
    session[:observation] = nil
    session[:image_ids] = query_ids("select id, `when` from images order by `when` desc")

    store_location
    @user = session['user']
    @layout = calc_layout_params
    @obj_pages, @objs = paginate(:images,
                                     :order => "`when` desc",
                                     :per_page => @layout["count"])
  end

  # Display list of images sorted by title.
  # Not used by anyone.
  # Inputs: session['user']
  # Outputs: @images, @user
  def images_by_title
    session[:checklist_source] = :nothing
    session[:observation_ids] = nil
    session[:observation] = nil
    session[:image_ids] = nil
    store_location
    @user = session['user']
    @images = Image.find(:all, :order => "'title' asc, 'when' desc")
  end

  # Searches image notes, copyright, and consensus name (including author)
  # for all observations it's associated with.
  # Redirected from: pattern_search (search bar)
  # Inputs:
  #   session[:pattern]
  #   session['user']
  # Outputs:
  #   Renders list_images.
  def image_search
    store_location
    @user = session['user']
    @layout = calc_layout_params
    @pattern = session[:pattern] || ''
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
      show_selected_images("Images matching '#{@pattern}'",
        field_search(["n.search_name", "i.notes", "i.copyright_holder"], "%#{@pattern.gsub(/[*']/,"%")}%"),
        "n.search_name, `when` desc", :nothing)
    end
  end
  
  def show_selected_images(title, conditions, order, source)
    # If provided, link should be the arguments for link_to as a list of lists,
    # e.g. [[:action => 'blah'], [:action => 'blah']]
    show_selected_objs(title, conditions, order, source, :images, 'list_images')
  end

  # Show the 640x640 (max size) version of image.
  # Linked from: thumbnails, next/prev_image, images_by_title, etc.
  # Inputs: params[:id] (image), session['user']
  # Outputs: @image, @user, @invalid
  def show_image
    store_location
    @seq_key = params[:seq_key]
    @search_seq = params[:search_seq]
    @obs = params[:obs]
    @user = session['user']
    # This marks this page as invalid XHTML.  Has something to do with a
    # <div about=filename.jpg> tag.  What's that for??
    @invalid = true
    @image = Image.find(params[:id])
  end

  # Show the original size image.
  # Linked from: show_image
  # Inputs: params[:id] (image), session['user']
  # Outputs: @image, @user, @invalid
  def show_original
    store_location
    @user = session['user']
    # This marks this page as invalid XHTML.  Has something to do with a
    # <div about=filename.jpg> tag.  What's that for??
    @invalid = true
    @image = Image.find(params[:id])
  end
  
  def inc_image_from_obs_search(state, inc_func, direction)
    current_image_id = params[:id].to_i
    current_image = Image.find(current_image_id)
    new_image = nil
    current_observation_id = state.current_id
    current_observation = Observation.find(current_observation_id)
    logger.warn("inc_image_from_obs_search: start #{current_image_id}, #{current_observation_id}")
    if current_image && current_observation
      images = current_observation.images
      index = images.index(current_image)
      if index
        index += direction
        if 0 <= index && index < images.length # Have to check explicitly since foo[-1] is the not nil
          new_image = images[index]
        end
      end
      logger.warn("inc_image_from_obs_search: index #{index}")
      if new_image.nil?
        inc_func.call
        count = Observation.count
        logger.warn("inc_image_from_obs_search: before loop #{count}, #{state.current_id}, #{current_observation_id}")
        while current_observation_id != state.current_id
          current_observation_id = state.current_id
          logger.warn("inc_image_from_obs_search: in loop #{current_observation_id}")
          current_observation = Observation.find(current_observation_id)
          if current_observation
            if direction == -1
              new_image = current_observation.images[-1] # Start from the last image
            else
              new_image = current_observation.images[0]
            end
            count -= 1
            logger.warn("inc_image_from_obs_search: drop count #{count}")
            if new_image.nil? and count > 0
              inc_func.call()
            else
              logger.warn("inc_image_from_obs_search: new image #{new_image.id}")
            end
          end
        end
      end
    end
    if new_image.nil?
      flash_warning("No new image found")
      new_image = current_image
      logger.warn("inc_image_from_obs_search: No new image found: #{new_image.id}")
    end
    store_seq_state(state)
    logger.warn("inc_image_from_obs_search(key, current_id, query_type): just saved #{state.key}, #{state.current_id}, #{state.query_type}")
    redirect_to :action => 'show_image', :id => new_image, :seq_key => state.key
  end
  
  def inc_image(func_name, direction) # direction is 1 or -1 depending on if we're doing next or prev
    start = Time.now.to_f
    state = SequenceState.new(session, params, Image.connection, :images, logger)
    inc_func = state.method(func_name)
    @seq_key = params[:seq_key]
    @search_state = params[:search_state]
    case state.query_type
    when :images
      inc_func.call()
      store_seq_state(state) # Add key and timestamp
      id = state.current_id
      if id
        redirect_to(:action => 'show_image', :id => id, :seq_key => state.key, :start => start)
      else
        redirect_to(:action => 'list_rss_logs')
      end
      for (key, value) in session[:seq_states]
        if key == :count
          logger.warn("state dump: count; #{value}")
        else
          logger.warn("state dump: #{key} (#{key.class}): #{value[:query]}, #{value[:timestamp]}, #{value[:access_count]} (#{value[:current_id]}, #{value[:current_index]}, #{value[:next_id]}, #{value[:prev_id]})")
        end
      end
    when :observations
      # Need to walk through images for current observation, then walk through the remaining observations
      inc_image_from_obs_search(state, inc_func, direction)
    when :rss_logs
      inc_image_from_obs_search(state, inc_func, direction)
    end
  end

  def next_image
    inc_image("next", 1)
  end

  def prev_image
    inc_image("prev", -1)
  end

  # Form for uploading and adding images to an observation.
  # Linked from: show_observation, reuse_image, and
  #   create/edit_naming (via _show_images partial)
  # Inputs: params[:id] (observation), session['user']
  #   params[:upload][:image1-4]
  #   params[:image][:copyright_holder]
  #   params[:image][:when]
  #   params[:image][:license_id]
  #   params[:image][:notes]
  # Outputs: @image, @observation, @user
  #   @licenses     (options for license select menu)
  # Redirects to show_observation.
  def add_image
    @user = session['user']
    @observation = Observation.find(params[:id])
    if !check_user_id(@observation.user_id)
      redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation
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
      redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation
    end
  end

  def process_image(args, upload)
    @user = session['user']
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
        flash_error "Invalid image '#{name ? name : "???"}'."
      else
        @observation.log("Image created by #{@user.login}: #{@image.unique_format_name}", true)
        @observation.add_image(@image)
        @observation.save
        flash_notice "Uploaded image " + (name ? "'#{name}'" : "##{@image.id}") + "."
      end
    end
  end

  # Form used to remove one or more images from an observation (not destroy!)
  # Linked from: show_observation, create/edit_naming (via _show_images partial)
  # Inputs: params[:id] (observation), session['user']
  #   params[:observation][:id]
  #   params[:selected][image_id]       (value of "yes" means delete)
  # Outputs: @observation, @user
  # Redirects to show_observation.
  def remove_images
    @user = session['user']
    @observation = Observation.find(params[:id])
    if verify_user()
      if !check_user_id(@observation.user_id)
        redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation
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
                @observation.log("Image removed by #{@user.login}: #{image.unique_format_name(@user)}", false)
                flash_notice "Removed image ##{image_id}."
              end
            end
          end
        end
        redirect_to(:controller => 'observer', :action => 'show_observation', :id => @observation)
      end
    end
  end

  # Form for editing date/license/notes on an image.
  # Linked from: show_image/original
  # Inputs: params[:id] (image), session['user']
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  # Outputs: @image, @licenses, @user
  def edit_image
    @user = session['user']
    @image = Image.find(params[:id])
    @licenses = License.current_names_and_ids(@image.license)
    if verify_user()
      if !check_user_id(@image.user_id)
        redirect_to :action => 'show_image', :id => @image
      elsif request.method == :post
        @image.attributes = params[:image]
        @image.modified = Time.now
        if !@image.save
          flash_object_errors(@image)
        else
          for o in @image.observations
            o.log(sprintf('Image, %s, updated by %s', @image.unique_text_name(@user), @user.login), true)
          end
          flash_notice "Image was successfully updated."
          redirect_to :action => 'show_image', :id => @image
        end
      end
    end
  end

  # Callback to destroy an image.
  # Should this be allowed?  How do we cleanup corresponding observations?
  # Linked from: show_image/original
  # Inputs: params[:id] (image), session['user']
  # Redirects to list_images.
  def destroy_image
    @user = session['user']
    @image = Image.find(params[:id])
    if verify_user()
      if !check_user_id(@image.user_id)
        redirect_to :action => 'show_image', :id => @image
      else
        image_name = @image.unique_text_name(@user)
        for observation in Observation.find(:all, :conditions => sprintf("thumb_image_id = '%s'", @image.id))
          observation.log("Image destroyed by #{@user.login}: #{image_name}", false)
          observation.thumb_image_id = nil
          observation.save
        end
        @image.destroy
        flash_notice "Image destroyed."
        redirect_to :action => 'list_images'
      end
    end
  end

  # Browse through matrix of recent images to let a user reuse an image
  # they've already uploaded for another observation.
  # Linked from: show_observation
  # Inputs: params[:id] (observation), session['user']
  # Outputs: @images, @image_pages, @observation, @user, @layout
  # (See also add_image_to_obs and reuse_image_by_id.)
  def reuse_image
    @user = session['user']
    @observation = Observation.find(params[:id])
    if verify_user()
      if !check_user_id(@observation.user_id)
        redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation
      else
        # @image = Image.new
        # @image.copyright_holder = @user.legal_name
        @layout = calc_layout_params
        @image_pages, @images = paginate(:images,
                                         :order => "'when' desc",
                                         :per_page => @layout["count"])
      end
    end
  end

  # First post method for reuse_image: user has clicked on one of the images.
  # Add this image to the new observation.
  # Inputs:
  #   params[:id]       (image)
  #   params[:obs_id]   (observation)
  #   session['user']
  # Redirects to show_observation.
  def add_image_to_obs
    @user = session['user']
    @observation = Observation.find(params[:obs_id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:id])
      if !image.nil?
        @observation.log("Image reused by #{@user.login}: #{image.unique_format_name(@user)}", true)
        flash_notice "Added image ##{image.id}."
      end
    end
    redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation
  end

  # Second post method for reuse_image: user has entered an image id in the
  # text field.  Add this image (assuming it exists!) to the new observation.
  # Inputs:
  #   params[:observation][:id]     (observation)
  #   params[:observation][:idstr]  (image)
  #   session['user']
  # Redirects to show_observation.
  def reuse_image_by_id
    @user = session['user']
    @observation = Observation.find(params[:observation][:id])
    if check_user_id(@observation.user_id)
      image = @observation.add_image_by_id(params[:observation][:idstr].to_i)
      if !image.nil?
        @observation.log("Image reused by #{@user.login}: #{image.unique_format_name(@user)}", true)
        flash_notice "Added image ##{image.id}."
      end
    end
    redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation
  end

  # Tabular form that lets user change licenses of their images.  The table
  # groups all the images of a given copyright holder and license type into
  # a single row.  This lets you change all of Rolf's licenses in one stroke.
  # Linked from: account/prefs
  # Inputs: session['user']
  #   params[:updates][license_id][copyright_holder]   (new license_id)
  # Outputs: @data, @user
  #   @data[n]['copyright_holder']  Person who actually holds copyright.
  #   @data[n]['license_count']     Number of images this guy holds with this type of license.
  #   @data[n]['selected']          ID of current license.
  #   @data[n]['license_id']        ID of current license.
  #   @data[n]['license_name']      Name of current license.
  #   @data[n]['select_id']         ID of HTML select menu element.
  #   @data[n]['select_name']       Name of HTML select menu element.
  #   @data[n]['licenses']          Options for select menu.
  def license_updater
    @user = session['user']
    if verify_user()
      #
      # Process any changes.
      if request.method == :post
        for current_id, value in params[:updates]
          current_id = current_id.to_i
          for copyright_holder, new_id in value
            new_id = new_id.to_i
            if current_id != new_id
              for image in Image.find_all_by_copyright_holder_and_license_id(copyright_holder, current_id)
                image.license_id = new_id
                image.save
              end
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

  # ----------------------------
  #  Testing.
  # ----------------------------

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
      user= session['user']
      @log_entry.upload_data_start = Time.now # Just in case save takes a long time
      count, size = test_process_image(user, params[:upload][:image1], 0, 0)
      count, size = test_process_image(user, params[:upload][:image2], count, size)
      count, size = test_process_image(user, params[:upload][:image3], count, size)
      count, size = test_process_image(user, params[:upload][:image4], count, size)
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
      @log_entry.user = session['user']
      @log_entry.save
      @upload = {}
    end
  end

  def test_add_image_report
    if verify_user()
      @log_entries = AddImageTestLog.find(:all, :order => 'created_at desc')
    end
  end

  # ----------------------------
  #  Admin tools.
  # ----------------------------

  def resize_images
    if check_permission(0)
      for image in Image.find(:all)
        image.calc_size()
        image.resize_image(160, 160, image.thumbnail)
      end
    else
      flash_error "You must be an admin to access resize_images."
    end
    redirect_to :action => 'list_images'
  end

  # ----------------------------
  #  Helpers.
  # ----------------------------

  # Get initial image_ids and observation_id
  helper_method :current_image_state
  def current_image_state
    observation_id = session[:observation]
    images_ids = nil
    obs_ids = session[:observation_ids]
    if obs_ids
      if observation_id.nil? and obs_ids
        if obs_ids.length > 0
          observation_id = obs_ids[0]
        end
      end
      image_ids = session[:image_ids]
      if image_ids.nil? and observation_id
        images = Observation.find(observation_id).images
        image_ids = []
        for i in images
          image_ids.push(i.id)
        end
      end
    end
    [image_ids, observation_id]
  end

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
