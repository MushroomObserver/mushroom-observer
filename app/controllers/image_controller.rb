# encoding: utf-8
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
#  vote_anonymity::        Change anonymity of image votes in bulk.
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
    :show_image,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Display matrix of selected images, based on current Query.
  def index_image # :nologin: :norobots:
    query = find_or_create_query(:Image, :by => params[:by])
    show_selected_images(query, :id => params[:id], :always_index => true)
  end

  # Display matrix of images, most recent first.
  def list_images # :nologin:
    query = create_query(:Image, :all, :by => :created)
    show_selected_images(query)
  end

  # Display matrix of images by a given user.
  def images_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:Image, :by_user, :user => user)
      show_selected_images(query)
    end
  end

  # Display matrix of images whose notes, names, etc. match a string pattern.
  def image_search # :nologin: :norobots:
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
  def advanced_search # :nologin: :norobots:
    begin
      query = find_query(:Image)
      show_selected_images(query)
    rescue => err
      flash_error(err.to_s) if !err.blank?
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
    args = {
      :action => 'list_images',
      :matrix => true,
      :include => [:user, {:observations => :name}],
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',          :sort_by_name.t],
      ['original_name', :sort_by_filename.t],
      ['date',          :sort_by_date.t],
      ['user',          :sort_by_user.t],
      # ['copyright_holder', :sort_by_copyright_holder.t],
      ['created',       :sort_by_posted.t],
      ['modified',      :sort_by_modified.t],
      ['confidence',    :sort_by_confidence.t],
      ['image_quality', :sort_by_image_quality.t],
      ['num_views',     :sort_by_num_views.t],
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
  def show_image # :nologin: :prefetch:
    store_location
    if @image = find_or_goto_index(Image, params[:id],
                        :include => [:user, {:observations => :name}])
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

      # Cast user's vote if passed in 'vote' parameter.
      if @user and
         (val = params[:vote]) and
         (val == '0' or (val = Image.validate_vote(val)))
        val = nil if val == '0'
        cur = @image.users_vote
        if cur != val
          anon = @user.votes_anonymous == :yes
          @image.change_vote(@user, val, anon)
          Transaction.put_images(:id => @image, :set_vote => val, :set_anonymous => anon)
        end
        
        # Advance to next image automatically if 'next' parameter set.
        if params[:next]
          query = find_or_create_query(Image)
          query.current = @image
          if query.index(@image) and
             (query = query.next)
            @image = query.current
          end
        end
      end

      # Grab list of votes.
      @votes = @image.image_votes(:include => :user).sort_by do |v|
        (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
      end

      # Update view stats on image we're actually showing.
      update_view_stats(@image)
    end
  end

  # For backwards compatibility.
  def show_original
    redirect_to(:action => 'show_image', :size => 'full_size', :id => params[:id])
  end

  # Go to next image: redirects to show_image.
  def next_image # :nologin: :norobots:
    redirect_to_next_object(:next, Image, params[:id])
  end

  # Go to previous image: redirects to show_image.
  def prev_image # :nologin: :norobots:
    redirect_to_next_object(:prev, Image, params[:id])
  end

  # Change user's vote and go to next image.
  def cast_vote # :norobots:
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
  def add_image # :prefetch: :norobots:
    pass_query_params
    @observation = Observation.find(params[:id])
    if !check_permission!(@observation)
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
      @image = Image.new(args)
      @image.created  = Time.now
      @image.modified = @image.created
      @image.user     = @user
      @image.image    = upload
      if !@image.save
        flash_object_errors(@image)
      elsif !@image.process_image
        logger.error("Unable to upload image")
        name = @image.original_name
        name = '???' if name.empty?
        flash_error(:runtime_image_invalid_image.t(:name => name))
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
        name = @image.original_name
        name = "##{@image.id}" if name.empty?
        flash_notice(:runtime_image_uploaded_image.t(:name => name))
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
    @image = Image.find(params[:id])
    @licenses = License.current_names_and_ids(@image.license)
    if !check_permission!(@image)
      redirect_to(:action => 'show_image', :id => @image,
                  :params => query_params)
    elsif request.method == :post
      @image.attributes = params[:image]
      xargs = {}
      xargs[:set_date]             = @image.when             if @image.when_changed?
      xargs[:set_notes]            = @image.notes            if @image.notes_changed?
      xargs[:set_copyright_holder] = @image.copyright_holder if @image.copyright_holder_changed?
      xargs[:set_original_name]    = @image.original_name    if @image.original_name_changed?
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
  def destroy_image # :norobots:

    # All of this just to decide where to redirect after deleting image.
    @image = Image.find(params[:id])
    next_state = nil
    if this_state = find_query(:Image)
      set_query_params(this_state)
      this_state.current = @image
      next_state = this_state.next
    end

    if !check_permission!(@image)
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
  def remove_image # :norobots:
    pass_query_params
    @image = Image.find(params[:image_id])
    @observation = Observation.find(params[:observation_id])
    if !check_permission!(@observation)
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
  def reuse_image # :norobots:
    pass_query_params
    @mode = params[:mode].to_sym
    @observation = Observation.find(params[:obs_id]) if @mode == :observation
    done = false

    # Make sure user owns the observation.
    if (@mode == :observation) and
       !check_permission!(@observation)
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
  def remove_images # :norobots:
    pass_query_params
    @observation = Observation.find(params[:id], :include => :images)

    # Make sure user owns the observation.
    if !check_permission!(@observation)
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
  #   params[:updates][n][:old_id]      (old license_id)
  #   params[:updates][n][:new_id]      (new license_id)
  #   params[:updates][n][:old_holder]  (old copyright holder)
  #   params[:updates][n][:new_holder]  (new copyright holder)
  # Outputs: @data
  #   @data[n]['copyright_holder']  Person who actually holds copyright.
  #   @data[n]['license_count']     Number of images this guy holds with this type of license.
  #   @data[n]['license_id']        ID of current license.
  #   @data[n]['license_name']      Name of current license.
  #   @data[n]['licenses']          Options for select menu.
  def license_updater # :norobots:

    # Process any changes.
    if request.method == :post
      data = params[:updates]
      for row in data.values
        old_id = row[:old_id].to_i
        new_id = row[:new_id].to_i
        old_holder = row[:old_holder].to_s
        new_holder = row[:new_holder].to_s
        if old_id != new_id or
           old_holder != new_holder
          old_license = License.find(old_id)
          new_license = License.find(new_id)
          old_holder = Image.connection.quote(old_holder);
          new_holder = Image.connection.quote(new_holder);
          data = Image.connection.select_rows(%(
            SELECT id, YEAR(`when`) FROM images
            WHERE user_id = #{@user.id}
              AND license_id = #{old_id}
              AND copyright_holder = #{old_holder}
          ))
          Image.connection.insert(%(
            INSERT INTO copyright_changes
              (user_id, modified, target_type, target_id, year, name, license_id)
            VALUES
              #{data.map {|id, year| "(#{@user.id},NOW(),'Image',#{id},#{year},#{old_holder},#{old_id})"}.join(",\n") }
          ))
          Image.connection.update(%(
            UPDATE images SET license_id = #{new_id}, copyright_holder = #{new_holder}
            WHERE user_id = #{@user.id}
              AND license_id = #{old_id}
              AND copyright_holder = #{old_holder}
          ))
          Transaction.put_image(
            :user                 => @user,
            :license              => old_license,
            :set_license          => new_license,
            :copyright_holder     => old_holder,
            :set_copyright_holder => new_holder
          )
        end
      end
    end

    # Gather data for form.
    @data = Image.connection.select_all(%(
      SELECT COUNT(*) AS license_count, copyright_holder, license_id
      FROM images
      WHERE user_id = #{@user.id.to_i}
      GROUP BY copyright_holder, license_id
    ))
    for datum in @data
      license = License.find(datum['license_id'].to_i)
      datum['license_name'] = license.display_name
      datum['licenses']     = License.current_names_and_ids(license)
    end
  end

  # Bulk update anonymity of user's image votes.
  # Input: params[:commit] - which button user pressed
  # Outputs:
  #   @num_anonymous - number of existing anonymous votes
  #   @num_public    - number of existing puclic votes
  def vote_anonymity
    if request.method == :post
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
        flash_error(:image_vote_anonymity_invalid_submit_button.l(:label => submit))
      end
      redirect_to(:controller => 'account', :action => 'prefs')
    else
      @num_anonymous = ImageVote.connection.select_value %(
        SELECT count(id) FROM image_votes WHERE user_id = #{@user.id} AND anonymous
      )
      @num_public = ImageVote.connection.select_value %(
        SELECT count(id) FROM image_votes WHERE user_id = #{@user.id} AND !anonymous
      )
    end
  end
end
