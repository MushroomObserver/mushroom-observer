require 'find'
require 'ftools'

################################################################################
#
#  Views: ("*" - login required; "R" - root only)
#     index
#   * login
#     rss
#     list_rss_logs
#     show_rss_log
#
#     show_observation
#     next_observation
#     prev_observation
#   * create_observation
#   * edit_observation
#   * destroy_observation
#   * create_naming
#   * edit_naming
#   * destroy_naming
#   * cast_vote
#     show_votes
#
#     show_notifications
#     list_notifications
#
#     list_observations
#     observations_by_name
#     show_user_observations
#     show_location_observations
#
#     pattern_search
#     observation_search
#     location_search
#
#   R users_by_name
#     users_by_contribution
#     show_user
#     show_site_stats
#
#     ask_webmaster_question
#   R email_features
#   R send_feature_email
#   * ask_user_question
#   * send_user_question
#   * ask_observation_question
#   * send_observation_question
#   * commercial_inquiry
#   * send_commercial_inquiry
#
#     intro
#     how_to_help
#     how_to_use
#     news
#     textile_sandbox
#
#     color_themes
#     Agaricus
#     Amanita
#     Cantharellus
#     Hygrocybe
#
#  Test Views:
#     throw_error
#   * throw_mobile_error
#
#  Admin Tools:
#     recalc
#   * refresh_vote_cache
#   * clear_session
#
#  Helpers:
#    show_selected_observations(title, conditions, order, source=:nothing, links=nil)
#    email_question(user, target_page, target_obj)
#    rewrite_url(obj, old_method, new_method)
#
################################################################################

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [
    :ask_webmaster_question,
    :color_themes,
    :how_to_help,
    :how_to_use,
    :index,
    :intro,
    :list_observations,
    :list_rss_logs,
    :location_search,
    :news,
    :next_observation,
    :observation_search,
    :observations_by_name,
    :pattern_search,
    :prev_observation,
    :recalc,
    :rss,
    :show_location_observations,
    :show_observation,
    :show_rss_log,
    :show_site_stats,
    :show_user,
    :show_user_observations,
    :show_votes,
    :textile_sandbox,
    :throw_error,
    :users_by_contribution
  ])

  # Default page.  Just displays latest happenings.
  # View: list_rss_logs
  # Inputs: none
  # Outputs: none
  def index
    list_rss_logs
    render(:action => 'list_rss_logs')
  end

  # Provided just as a way to verify the before_filter.
  # This page should always require the user to be logged in.
  # View: list_rss_logs
  # Inputs: none
  # Outputs: none
  def login
    list_rss_logs
    render(:action => 'list_rss_logs')
  end

  # Another test method.  Repurpose as needed.
  def throw_error
    raise "Something bad happened"
  end

  # Used for initial investigation of specialized mobile support
  def throw_mobile_error
    if request.env["HTTP_USER_AGENT"].index("BlackBerry")
      raise "This is a BlackBerry!"
    else
      raise "#{request.env["HTTP_USER_AGENT"]}"
    end
  end

  # Linked from the left hand column.
  def how_to_use
    @min_pos_vote = Vote.agreement(Vote.min_pos_vote).l
    @min_neg_vote = Vote.agreement(Vote.min_neg_vote).l
    @maximum_vote = Vote.agreement(Vote.maximum_vote).l
  end

  # Simple form letting us test our implementation of Textile.
  def textile_sandbox
    if request.method != :post
      @code = nil
    else
      @code = params[:code]
    end
  end

  # So you can start with a clean slate
  def clear_session
    session[:seq_states] = { :count => 0 }
    session[:search_states] = { :count => 0 }
    redirect_to(:action => "list_rss_logs")
  end

  # Perform the various searches.
  # Linked from: search bar
  # Inputs:
  #   params[:commit]
  #   params[:search][:pattern]
  # Redirects to one of these:
  #   image_search
  #   name_search
  #   list_place_names
  #   observation_search
  def pattern_search
    store_location
    @layout = calc_layout_params
    search_data = params[:search]
    if search_data
      session[:pattern] = search_data[:pattern]
    end
    pattern = session[:pattern]
    if pattern.nil?
      pattern = ''
    end
    # [params[:commit] == nil means observation_search -- don't we want to save that???  -JPH 20080313]
    if params[:commit]
      session[:search_type] = params[:commit]
    end
    case session[:search_type]
    when :app_images_find.l
      redirect_to(:controller => 'image', :action => 'image_search')
    when :app_names_find.l
      redirect_to(:controller => 'name', :action => 'name_search')
    when :app_locations_find.l
      redirect_to(:controller => 'location', :action => 'list_place_names', :pattern => pattern)
    else
      redirect_to(:controller => 'observer', :action => 'observation_search')
    end
  end

#--#############################################################################
#
#  Observation support.
#
#  Views:
#    list_observations              All obvs, by date.
#    observations_by_name           All obvs, by name.
#    show_user_observations         User's obvs, by date.
#    show_location_observations     Obvs at a defined location, by name.
#    observation_search             Obvs that match a string.
#    location_search                Obvs whose location matches a string.
#
#    show_notifications             Shows notifications triggered by a naming.
#    list_notifications             Shows notifications created by a user.
#
#    show_observation               Show observation.
#    prev_observation               Go to previous observation.
#    next_observation               Go to next observation.
#
#    create_observation             Create new observation.
#    edit_observation               Edit existing observation.
#    destroy_observation            Destroy observation.
#
#    create_naming                  Create new naming.
#    edit_naming                    Edit existing naming.
#    destroy_naming                 Destroy naming.
#
#  Debugging
#    recalc                         Recalcs consensus and renders show_obs.
#
#  Helpers:
#    show_selected_observations(...)
#
#++#############################################################################

  def show_selected_observations(title, conditions, order, source=:nothing, links=nil)
    # If provided, link should be the arguments for link_to as a list of lists,
    # e.g. [[:action => 'blah'], [:action => 'blah']]
    show_selected_objs(title, conditions, order, source, :observations, 'list_observations', links)
  end

  # Displays matrix of all observations, sorted by date.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs: @observations, @observation_pages, @layout
  def list_observations
    show_selected_observations("Observations", "", "observations.`when` desc", :all_observations)
  end

  # Displays matrix of all observations, alphabetically.
  # Linked from: nowhere
  # View: list_observations
  # Outputs: @observations, @observation_pages, @layout
  def observations_by_name
    show_selected_observations("Observations", "",
      "names.search_name asc, observations.`when` desc", :all_observations)
  end

  # Displays matrix of user's observations, by date.
  # Linked from: left panel, show_user, users_by_contribution
  # View: list_observations
  # Inputs: params[:id] (user id)
  # Outputs: @observations, @observation_pages, @layout
  def show_user_observations
    user = User.find(params[:id])
    show_selected_observations("Observations by %s" % user.legal_name,
      "observations.user_id = %s" % user.id,
      "observations.modified desc, observations.`when` desc")
  end

  # Searches for observations based on location, notes and consensus name
  # (including author).
  # Redirected from: pattern_search
  # View: list_observations
  # Inputs:
  #   session[:pattern]
  # Outputs: @observations, @observation_pages, @layout
  def observation_search
    store_location
    @layout = calc_layout_params
    @pattern = session[:pattern] || ''
    id = @pattern.to_i
    obs = nil
    if @pattern == id.to_s
      begin
        obs = Observation.find(id)
      rescue ActiveRecord::RecordNotFound
      end
    end
    if obs
      redirect_to(:action => "show_observation", :id => id)
    else
      show_selected_observations("Observations matching '#{@pattern}'",
        field_search(["names.search_name", "observations.where",
          "observations.notes", "locations.display_name"], "%#{@pattern.gsub(/[*']/,"%")}%"),
        "names.search_name asc, observations.`when` desc")
    end
  end

  # Displays matrix of observations at a location, alphabetically.
  # Linked from: show_location
  # View: list_observations
  # Inputs: params[:id] (location id)
  # Outputs: @observations, @observation_pages, @layout
  def show_location_observations
    loc = Location.find(params[:id])
    show_selected_observations("Observations from %s" % loc.display_name,
      "observations.location_id = %s" % loc.id,
      "names.search_name, observations.`when` desc", :nothing,
      [[:location_show_map.l, {:controller => 'location', :action => 'show_location', :id => loc.id}]])
  end

  # Display matrix of observations whose location matches a string.
  # Redirected from: where_search
  # View: list_pbservations
  # Inputs: pattern
  # Outputs: @observations, @observation_pages, @layout
  def location_search
    # Looks harder for pattern since location_controller.where_search was using :pattern for a bit
    # and some of the search monkeys picked up on it.
    pattern = session[:where] || session[:pattern] || ""
    sql_pattern = "%#{pattern.gsub(/[*']/,"%")}%"
    show_selected_observations("Observations from '#{pattern}'", "observations.where like '#{sql_pattern}'",
      "names.search_name asc, observations.`when` desc", :nothing,
      [[:location_define.l, {:controller => 'location', :action => 'create_location', :where => pattern}],
       [:location_merge.l, {:controller => 'location', :action => 'list_merge_options', :where => pattern}],
       [:location_all.l, {:controller => 'location', :action => 'list_place_names'}]])
  end

  # Displays notifications related to a given naming and users.
  # Inputs: params[:naming], params[:observation]
  # Outputs:
  #   @notifications
  def show_notifications
    data = []
    @observation = Observation.find(params[:id])
    for q in QueuedEmail.find_all_by_flavor_and_to_user_id(:naming, @user.id)
      naming_id, notification_id, shown = q.get_integers([:naming, :notification, :shown])
      if shown.nil?
        notification = Notification.find(notification_id)
        if notification.note_template
          data.push([notification, Naming.find(naming_id)])
        end
        q.add_integer(:shown, 1)
      end
    end
    @data = data.sort_by { rand }
  end

  # Lists notifications that the given user has created.
  # Inputs: none
  # Outputs:
  #   @notifications
  def list_notifications
    if verify_user()
      @notifications = Notification.find_all_by_user_id(@user.id, :order => :flavor)
    end
  end

  # Display observation and related namings, comments, votes, images, etc.
  # This should be redirected_to, not rendered, due to large number of
  # @variables that need to be set up for the view.  Lots of views are used:
  #   show_observation
  #   _show_observation
  #   _show_images
  #   _show_namings
  #   _show_comments
  #   _show_footer
  # Linked from countless views as a fall-back.
  # Inputs: params[:id]
  # Outputs:
  #   @observation
  #   @confidence/agreement_menu    (used to create vote menus)
  #   @votes                        (user's vote for each naming.id)
  def show_observation
    seq_key = params[:seq_key]
    if seq_key.nil?
      params[:obs] = params[:id]
      state = SequenceState.lookup(params, :rss_logs, logger)
      state.save if !is_robot?
      seq_key = state.id
    end
    store_location # Is this doing anything useful since there is no user check for this page?
    pass_seq_params()
    @seq_key = seq_key
    @observation = Observation.find(params[:id])
    session[:observation] = params[:id].to_i
    session[:image_ids] = nil
    @confidence_menu = translate_menu(Vote.confidence_menu)
    @agreement_menu  = translate_menu(Vote.agreement_menu)
    @votes = Hash.new
    if @user && @user.verified
      #
      # This happens when user clicks on "Update Votes".
      if request.method == :post
        #
        # Change user's votes?
        if params[:vote]
          flashed = false
          for naming_id in params[:vote].keys
            if params[:vote][naming_id] && params[:vote][naming_id][:value]
              naming = Naming.find(naming_id)
              value = params[:vote][naming_id][:value].to_i
              if naming.change_vote(@user, value) && !flashed
                flash_notice "Successfully changed vote."
                flashed = true
              end
            end
          end
          # Seems to need this to catch change in preferred name.
          @observation.reload if flashed
        end
      end
      #
      # Provide a list of user's votes to view.
      for naming in @observation.namings
        vote = naming.votes.find(:first,
          :conditions => ['user_id = ?', @user.id])
        if vote.nil?
          vote = Vote.new(:value => 0)
        end
        @votes[naming.id] = vote
      end
    end
  end

  # Go to next observation: renders show_observation.
  def next_observation
    state = SequenceState.lookup(params, :observations, logger)
    state.next()
    state.save if !is_robot?
    id = state.current_id
    if id
      redirect_to(:action => 'show_observation', :id => id,
        :search_seq => params[:search_seq], :seq_key => state.id)
    else
      redirect_to(:action => 'list_rss_logs')
    end
  end

  # Go to previous observation: renders show_observation.
  def prev_observation
    state = SequenceState.lookup(params, :observations, logger)
    state.prev()
    state.save !is_robot?
    id = state.current_id
    if id
      redirect_to(:action => 'show_observation', :id => id,
        :search_seq => params[:search_seq], :seq_key => state.id)
    else
      redirect_to(:action => 'list_rss_logs')
    end
  end

  # Form to create a new observation, naming, vote, and images.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:observation][...]         observation args
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:image][n][...]            image args
  #   params[:good_images]              images already downloaded
  #   params[:was_js_on]                was form javascripty? ('yes' = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @confidence_menu                  used for vote option menu
  #   @reason                           array of naming_reasons
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already downloaded
  #
  def create_observation
    if verify_user()
      # These are needed to create pulldown menus in form.
      @licenses = License.current_names_and_ids(@user.license)
      @new_image = init_image(Time.now)
      @confidence_menu = translate_menu(Vote.confidence_menu)

      # Clear search list.
      session_setup

      # Create empty instances first time through.
      if request.method != :post
        @observation = Observation.new
        @naming      = Naming.new
        @vote        = Vote.new
        @what        = '' # can't be nil else rails tries to call @name.name
        @names       = nil
        @valid_names = nil
        @reason      = init_naming_reasons()
        @images      = []
        @good_images = []

      else
        # Create everything roughly first.
        @observation = create_observation_object(params[:observation])
        @naming      = create_naming_object(params[:naming], @observation)
        @vote        = create_vote_object(params[:vote], @naming)
        @good_images = update_good_images(params[:good_images])
        @bad_images  = create_image_objects(params[:image], @observation, @good_images)

        # Validate name.
        (success, @what, @name, @names, @valid_names) = resolve_name(
          (params[:name] ? params[:name][:name] : nil),
          params[:approved_name],
          (params[:chosen_name] ? params[:chosen_name][:name_id] : nil)
        )
        @naming.name = @name if @name

        # Validate objects.
        success = validate_observation(@observation) if success
        success = validate_naming(@naming) if @name && success
        success = validate_vote(@vote)     if @name && success
        success = false                    if @bad_images != []

        # If everything checks out save observation.
        if success &&
          (success = save_observation(@observation))
          flash_notice 'Observation was successfully created.'
          @observation.log("Observation created by #{@user.login}.", true)
        end

        # Once observation is saved we can save everything else.
        if success
          if @name
            save_naming(@naming)
            create_naming_reasons(@naming, params[:reason])
            @observation.reload
            @naming.change_vote(@user, @vote.value)
          end
          attach_good_images(@observation, @good_images)

          # Check for notifications.
          if has_unshown_notifications(@user, :naming)
            redirect_to(:action => 'show_notifications', :id => @observation.id)
          else
            redirect_to(:action => 'show_observation', :id => @observation.id)
          end

        # If anything failed reload the form.
        else
          @reason = init_naming_reasons(params[:reason])
          @images = @bad_images
          @new_image.when = @observation.when
        end
      end
    end
  end

  # Form to edit an existing observation.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:id]                       observation id
  #   params[:observation][...]         observation args
  #   params[:image][n][...]            image args
  #   params[:log_change][:checked]     log change in RSS feed?
  #
  # Outputs:
  #   @observation                      populated object
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already attached
  #
  def edit_observation
    if verify_user()
      @observation = Observation.find(params[:id])
      @licenses = License.current_names_and_ids(@user.license)
      @new_image = init_image(@observation.when)

      # Make sure user owns this observation!
      if !check_user_id(@observation.user_id)
        redirect_to(:action => 'show_observation', :id => @observation.id)

      # Initialize form.
      elsif request.method != :post
        @images      = []
        @good_images = @observation.images

      else
        # Update observation first.
        success = update_observation_object(@observation, params[:observation])

        # Now try to upload images.
        @good_images = update_good_images(params[:good_images])
        @bad_images  = create_image_objects(params[:image], @observation, @good_images)
        attach_good_images(@observation, @good_images)

        # Only save observation if there are changes.
        if success && @observation.changed?
          @observation.modified = Time.now
          if success = save_observation(@observation)
            flash_notice 'Observation was successfully updated.'
            @observation.log("Observation updated by #{@user.login}.",
              (params[:log_change] ? (params[:log_change][:checked] == '1') : false))
          end
        end

        # Redirect to show_observation on success.
        if success && @bad_images == []
          redirect_to(:action => 'show_observation', :id => @observation.id)

        # Reload form if anything failed.
        else
          @images = @bad_images
          @new_image.when = @observation.when
        end
      end
    end
  end

  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects to list_observations.
  def destroy_observation
    if verify_user()
      @observation = Observation.find(params[:id])
      if !check_user_id(@observation.user_id)
        flash_error 'You do not own this observation.'
        redirect_to(:action => 'show_observation', :id => @observation.id)
      else
        for spl in @observation.species_lists
          spl.log(sprintf('Observation, %s, destroyed by %s',
            @observation.unique_text_name, @user.login))
        end
        @observation.orphan_log("Observation destroyed by #{@user.login}")
        @observation.namings.clear # (takes votes with it)
        @observation.comments.clear
        @observation.destroy
        flash_notice 'Successfully destroyed observation.'
        redirect_to(:action => 'list_observations')
      end
    end
  end

  # Form to propose new naming for an observation.
  # Linked from: show_observation
  #
  # Inputs (post):
  #   params[:id]                       observation id
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:was_js_on]                was form javascripty? ('yes' = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @confidence_menu                  used for vote option menu
  #   @reason                           array of naming_reasons
  #
  def create_naming
    pass_seq_params()
    if verify_user()
      @observation = Observation.find(params[:id])
      @confidence_menu = translate_menu(Vote.confidence_menu)

      # Create empty instances first time through.
      if request.method != :post
        @naming      = Naming.new
        @vote        = Vote.new
        @what        = '' # can't be nil else rails tries to call @name.name
        @names       = nil
        @valid_names = nil
        @reason      = init_naming_reasons()

      else
        # Create everything roughly first.
        @naming = create_naming_object(params[:naming], @observation)
        @vote   = create_vote_object(params[:vote], @naming)

        # Validate name.
        (success, @what, @name, @names, @valid_names) = resolve_name(
          (params[:name] ? params[:name][:name] : nil),
          params[:approved_name],
          (params[:chosen_name] ? params[:chosen_name][:name_id] : nil)
        )
        success = false if !@name

        if success && @observation.name_been_proposed?(@name)
          flash_warning 'Someone has already proposed that name.  If you would
            like to comment on it, try posting a comment instead.'
          success = false
        end

        # Validate objects.
        @naming.name = @name
        success = validate_naming(@naming) if success
        success = validate_vote(@vote)     if success

        if success
          # Save changes now that everything checks out.
          save_naming(@naming)
          create_naming_reasons(@naming, params[:reason])
          @observation.reload
          @naming.change_vote(@user, @vote.value)
          @observation.log("Naming created by #{@user.login}: #{@naming.format_name}", true)

          # Check for notifications.
          if has_unshown_notifications(@user, :naming)
            redirect_to(:action => 'show_notifications', :id => @observation.id)
          else
            redirect_to(:action => 'show_observation', :id => @observation.id, :params => calc_search_params)
          end

        # If anything failed reload the form.
        else
          @reason = init_naming_reasons(params[:reason])
        end
      end
    end
  end

  # Form to edit an existing naming for an observation.
  # Linked from: show_observation
  #
  # Inputs:
  #   params[:id]                       naming id
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:was_js_on]                was form javascripty? ('yes' = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @confidence_menu                  used for vote option menu
  #   @reason                           array of naming_reasons
  #
  def edit_naming
    if verify_user()
      @naming = Naming.find(params[:id])
      @observation = @naming.observation
      @vote = Vote.find(:first, :conditions =>
        ['naming_id = ? AND user_id = ?', @naming.id, @naming.user_id])
      @confidence_menu = translate_menu(Vote.confidence_menu)

      # Make sure user owns this naming!
      if !check_user_id(@naming.user_id)
        redirect_to(:action => 'show_observation', :id => @observation.id, :params => calc_search_params)

      # Initialize form.
      elsif request.method != :post
        @what        = @naming.text_name
        @names       = nil
        @valid_names = nil
        @reason      = init_naming_reasons(nil, @naming)

      else
        # Validate name.
        (success, @what, @name, @names, @valid_names) = resolve_name(
          (params[:name] ? params[:name][:name] : nil),
          params[:approved_name],
          (params[:chosen_name] ? params[:chosen_name][:name_id] : nil)
        )
        success = false if !@name

        if success && @naming.name != @name && @observation.name_been_proposed?(@name)
          flash_warning 'Someone has already proposed that name.  If you would
            like to comment on it, try posting a comment instead.'
          success = false
        end

        # Owner is not allowed to change a naming once it's been used by someone
        # else.  Instead I automatically clone it and make changes to the clone.
        # I assume there will be no validation problems since we're cloning
        # pre-existing valid objects.
        if success && !@naming.editable? && @name != @naming.name
          @naming = create_naming_object(params[:naming], @observation)
          @vote   = create_vote_object(params[:vote], @naming)

          # Validate objects.
          @naming.name = @name
          success = validate_naming(@naming) if success
          success = validate_vote(@vote)     if success

          # Save changes now that everything checks out.
          if success
            save_naming(@naming)
            create_naming_reasons(@naming, params[:reason])
            @observation.reload
            @naming.change_vote(@user, @vote.value)
            @observation.log("Naming created by #{@user.login}: #{@naming.format_name}", true)
            flash_warning 'Sorry, someone else has given this a positive vote,
              so we had to create a new Naming to accomodate your changes.'
          end

        # Owner is allowed to change the naming so long as no one else has used it.
        # They are also allowed to change the reasons even if others have used it.
        elsif success

          # If user's changed the name, it sorta invalidates any votes that
          # others might have cast prior to this.
          need_to_calc_consensus = false
          need_to_log_change = false
          if @name != @naming.name
            for vote in @naming.votes
              vote.destroy if vote.user_id != @user.id
            end
            need_to_calc_consensus = true
            need_to_log_change = true
          end

          # Make changes to naming.
          success = update_naming_object(@naming, @name, need_to_log_change)

          # Save everything if it all checks out.
          if success
            @naming.naming_reasons.clear
            create_naming_reasons(@naming, params[:reason])

            # Only change vote if changed value.
            if params[:vote] && (!@vote || @vote.value != params[:vote][:value].to_i)
              @naming.change_vote(@user, params[:vote][:value].to_i)
              need_to_calc_consensus = false
            end
            if need_to_calc_consensus
              @observation.reload
              @observation.calc_consensus
            end
          end
        end

        # Redirect to observation on success, reload form if anything failed.
        if success
          redirect_to(:action => 'show_observation', :id => @observation.id, :params => calc_search_params)
        else
          @reason = init_naming_reasons(params[:reason], @naming)
        end
      end
    end
  end

  # Callback to destroy a naming (and associated votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects back to show_observation.
  def destroy_naming
    @naming = Naming.find(params[:id])
    @observation = @naming.observation
    if !check_user_id(@naming.user_id)
      flash_error 'You do not own that naming.'
      redirect_to(:action => 'show_observation', :id => @observation.id)
    elsif !@naming.deletable?
      flash_warning 'Sorry, someone else has given this their strongest
        positive vote.  You are free to propose alternate names,
        but we can no longer let you delete this name.'
      redirect_to(:action => 'show_observation', :id => @observation.id)
    else
      @naming.observation.log("Naming deleted by #{@user.login}: #{@naming.format_name}", true)
      @naming.votes.clear
      @naming.destroy
      @observation.calc_consensus
      flash_notice 'Successfully destroyed naming.'
      redirect_to(:action => 'show_observation', :id => @observation.id)
    end
  end

  # I'm tired of tweaking show_observation to call calc_consensus for debugging.
  # I'll just leave this stupid action in and have it forward to show_observation.
  def recalc
    id = params[:id]
    begin
      @observation = Observation.find(id)
      flash_notice "old_name: #{@observation.name.text_name}"
      text = @observation.calc_consensus(true)
      flash_notice text if !text.nil? && text != ''
      flash_notice "new_name: #{@observation.name.text_name}"
    rescue
      flash_error 'Caught exception.'
    end
    # render(:text => '', :layout => true)
    redirect_to(:action => 'show_observation', :id => id)
  end

#--#############################################################################
#
#  Vote support.
#
#  Views:
#    cast_vote
#    show_votes
#
#++#############################################################################

  # Create vote if none exists; change vote if exists; delete vote if setting
  # value to -1 (owner of naming is not allowed to do this).
  # Linked from: show_observation
  # Inputs: params[]
  # Redirects to show_observation.
  def cast_vote
    if verify_user()
      if !params[:vote] || !params[:vote][:value]
        raise "Invoked cast_vote without any parameters!"
      else
        naming = Naming.find(params[:vote][:naming_id])
        value = params[:vote][:value].to_i
        naming.change_vote(@user, value)
        redirect_to(:action => 'show_observation', :id => naming.observation.id)
      end
    end
  end

  # Show breakdown of votes for a given naming.
  # Linked from: show_observation
  # Inputs: params[:id] (naming)
  # Outputs: @naming
  def show_votes
    @naming = Naming.find(params[:id])
  end

  # I'm going to let anyone who's logged in do this for now.
  def refresh_vote_cache
    # Naming.refresh_vote_cache
    Observation.refresh_vote_cache
    flash_notice "Refreshed vote caches."
    redirect_to(:action => 'index')
  end

#--#############################################################################
#
#  User support.
#
#    users_by_name
#    users_by_contribution
#    show_user
#    show_site_stats
#
#++#############################################################################

  # users_by_name.rhtml
  # Restricted to the admin user
  def users_by_name
    if check_permission(0)
      @users = User.find(:all, :order => "last_login desc")
    else
      redirect_to(:action => 'list_observations')
    end
  end

  # users_by_contribution.rhtml
  def users_by_contribution
    SiteData.new
    @users = User.find(:all, :order => "contribution desc")
  end

  # show_user.rhtml
  def show_user
    store_location
    id = params[:id]
    @show_user = User.find(id)
    @user_data = SiteData.new.get_user_data(id)
    @observations = Observation.find(:all, :conditions => ["user_id = ? and thumb_image_id is not null", id],
      :order => "id desc", :limit => 6)
  end

  # show_site_stats.rhtml
  def show_site_stats
    store_location
    @site_data = SiteData.new.get_site_data
    @observations = Observation.find(:all, :conditions => ["thumb_image_id is not null"],
      :order => "id desc", :limit => 6)
  end

#--#############################################################################
#
#  Email support.
#
#  Views:
#    ask_webmaster_question     (get and post methods)
#    email_features
#    send_feature_email         (post method)
#    ask_question
#    send_question              (post method)
#    commercial_inquiry
#    send_commercial_inquiry    (post method)
#
#++#############################################################################

  def ask_webmaster_question
    @email = params[:user][:email] if params[:user]
    @content = params[:question][:content] if params[:question]
    @email_error = false
    if request.method == :get
      @email = @user.email if @user
    elsif @email.nil? or @email.strip == '' or @email.index('@').nil?
      flash_error "You must provide a valid return address."
      @email_error = true
    elsif /http:/ =~ @content or /<[\/a-zA-Z]+>/ =~ @content
      flash_error "To cut down on robot spam, questions from unregistered users cannot contain 'http:' or HTML markup."
    elsif @content.nil? or @content.strip == ''
      flash_error "Missing question or content."
    else
      AccountMailer.deliver_webmaster_question(@email, @content)
      flash_notice "Delivered question or comment."
      redirect_back_or_default :action => "list_rss_logs"
    end
  end

  # email_features.rhtml
  # Restricted to the admin user
  def email_features
    if check_permission(0)
      @users = User.find(:all, :conditions => "feature_email=1 and verified is not null")
    else
      redirect_to(:action => 'list_observations')
    end
  end

  def send_feature_email
    if check_permission(0)
      users = User.find(:all, :conditions => "feature_email=1 and verified is not null")
      for user in users
        if user.feature_email
          FeatureEmail.create_email(user, params['feature_email']['content'])
        end
      end
      flash_notice "Delivered feature mail."
      redirect_to(:action => 'users_by_name')
    else
      flash_error "Only the admin can send feature mail."
      redirect_to(:action => "list_rss_logs")
    end
  end

  def email_question(user, target_page, target_obj)
    if !user.question_email
      flash_error "Permission denied"
      redirect_to(:action => target_page, :id => target_obj.id)
    end
  end

  def ask_user_question
    @target = User.find(params[:id])
    email_question(@target, 'show_user', @user)
  end

  def send_user_question
    sender = @user
    target = User.find(params[:id])
    subject = params[:email][:subject]
    content = params[:email][:content]
    AccountMailer.deliver_user_question(sender, target, subject, content)
    flash_notice "Delivered email."
    redirect_to(:action => 'show_user', :id => target.id)
  end

  def ask_observation_question
    @observation = Observation.find(params[:id])
    email_question(@observation.user, 'show_observation', @observation)
  end

  def send_observation_question
    sender = @user
    observation = Observation.find(params[:id])
    question = params[:question][:content]
    AccountMailer.deliver_observation_question(sender, observation, question)
    flash_notice "Delivered question."
    redirect_to(:action => 'show_observation', :id => observation.id)
  end

  def commercial_inquiry
    @image = Image.find(params[:id])
    if !@image.user.commercial_email
      flash_error "Permission denied."
      redirect_to(:action => 'show_image', :id => @image.id)
    end
  end

  def send_commercial_inquiry
    sender = @user
    image = Image.find(params[:id])
    commercial_inquiry = params[:commercial_inquiry][:content]
    AccountMailer.deliver_commercial_inquiry(sender, image, commercial_inquiry)
    flash_notice "Delivered commercial inquiry."
    redirect_to(:action => 'show_image', :id => image.id)
  end

#--#############################################################################
#
#  RSS support.
#
#  Views:
#    rss
#    list_rss_logs
#    show_rss_log
#
#++#############################################################################

  def rss
    headers["Content-Type"] = "application/xml"
    @logs = RssLog.find(:all, :order => "modified desc",
                        :conditions => "datediff(now(), modified) <= 31",
                        :limit => 100)
    render(:action => "rss", :layout => false)
  end

  # left-hand panel -> list_rss_logs.rhtml
  def list_rss_logs
    # Not exactly sure how this ties into SearchStates
    search_state = SearchState.lookup(params, :rss_logs, logger)
    unless search_state.setup?
      search_state.setup("Activity Log", nil, "modified desc", :nothing)
    end
    search_state.save if !is_robot?
    @search_seq = search_state.id

    store_location
    @layout = calc_layout_params
    session[:checklist_source] = :all_observations
    query = "select observation_id as id, modified from rss_logs where observation_id is not null and " +
            "modified is not null order by modified desc"
    session_setup
    @rss_log_pages, @rss_logs = paginate(:rss_log,
                                         :order => "modified desc",
                                         :per_page => @layout["count"])
  end

  def show_rss_log
    store_location
    @rss_log = RssLog.find(params['id'])
  end

#--#############################################################################
#
#  Create and edit helpers:
#
#    create_observation_object(...)     Create rough first-drafts.
#    create_naming_object(...)
#    create_vote_object(...)
#
#    validate_observation(...)          Validate first-drafts.
#    validate_naming(...)
#    validate_vote(...)
#
#    save_observation(...)              Save validated objects.
#    save_naming(...)
#
#    update_observation_object(...)     Update and save existing objects.
#    update_naming_object(...)
#
#    init_naming_reasons(...)           Handle naming reasons.
#    create_naming_reasons(...)
#
#    init_image()                       Handle image uploads.
#    create_image_objects(...)
#    update_good_images(...)
#    attach_good_images(...)
#
#    resolve_name(...)                  Validate name.
#
#++#############################################################################

  protected

  # Roughly create observation object.  Will validate and save later once we're sure everything is correct.
  # INPUT: params[:observation] (and @user)
  # OUTPUT: new observation
  def create_observation_object(args)
    now = Time.now
    observation = Observation.new(args)
    observation.created  = now
    observation.modified = now
    observation.user     = @user
    observation.name     = Name.unknown
    return observation
  end

  # Roughly create naming object.  Will validate and save later once we're sure everything is correct.
  # INPUT: params[:naming], observation (and @user)
  # OUTPUT: new naming
  def create_naming_object(args, observation)
    now = Time.now
    naming = Naming.new(args)
    naming.created     = now
    naming.modified    = now
    naming.user        = @user
    naming.observation = observation
    return naming
  end

  # Roughly create vote object.  Will validate and save later once we're sure everything is correct.
  # INPUT: params[:vote], naming (and @user)
  # OUTPUT: new vote
  def create_vote_object(args, naming)
    now = Time.now
    vote = Vote.new(args)
    vote.created     = now
    vote.modified    = now
    vote.user        = @user
    vote.naming      = naming
    vote.observation = naming.observation
    return vote
  end

  # Make sure there are no errors in observation.
  def validate_observation(observation)
    success = true
    if !observation.valid?
      flash_object_errors(observation)
      success = false
    end
    return success
  end

  # Make sure there are no errors in naming.
  def validate_naming(naming)
    success = true
    if !naming.valid?
      flash_object_errors(naming)
      success = false
    end
    return success
  end

  # Make sure there are no errors in vote.
  def validate_vote(vote)
    success = true
    if !vote.valid?
      flash_object_errors(vote)
      success = false
    end
    return success
  end

  # Save observation now that everything is created successfully.
  def save_observation(observation)
    success = true
    if !observation.save
      flash_error "Couldn't save observation."
      flash_object_errors(observation)
      success = false
    end
    return success
  end

  # Update observation, check if valid.
  def update_observation_object(observation, args)
    success = true
    observation.attributes = args
    if !observation.valid?
      session[:observation] = observation.id
      flash_object_errors(observation)
      success = false
    end
    return success
  end

  # Save naming now that everything is created successfully.
  def save_naming(naming)
    success = true
    if naming.save
      flash_notice 'Naming was successfully created.'
    else
      flash_warning "Couldn't save naming."
      flash_object_warnings(naming)
      success = false
    end
    return success
  end

  # Update naming and log changes.
  def update_naming_object(naming, name, log)

    # Only bother to save changes if there ARE changes!
    if naming.name != name
      naming.modified = Time.now
      naming.name = name
      naming.save
    end

    # (Might be changes to reasons, though, so we better log it anyway.)
    flash_notice 'Naming was successfully updated.'
    naming.observation.log("Naming changed by #{@user.login}: #{naming.format_name}", log)

    return true
  end

  # Initialize the naming_reasons objects used by the naming form.
  def init_naming_reasons(args=nil, naming=nil)
    result = {}

    # Get values from existing naming object.
    if naming
      for r in naming.naming_reasons
        result[r.reason] = r
      end
      for i in NamingReason.reasons
        if !result.has_key?(i)
          result[i] = NamingReason.new(:reason => i, :notes => nil)
        end
      end

    # Get values from params.
    else
      for i in NamingReason.reasons
        if args && (x = args[i.to_s])
          check = x[:check]
          notes = x[:notes]
          if check == '1' && notes.nil?
            notes = ''
          elsif check == '0' && notes == ''
            notes = nil
          end
        else
          notes = nil
        end
        result[i] = NamingReason.new(:reason => i, :notes => notes)
      end
    end

    return result
  end

  # Creates all the reasons for a naming.
  # Gets checkboxes and notes from params[:reason].
  # MUST BE CLEARED before calling this!
  def create_naming_reasons(naming, args)

    # Need to know if JS was on because it changes how we deal with unchecked
    # reasons that have notes: if JS is off these are considered valid, if JS
    # was on the notes are hidden when the box is unchecked thus it is invalid.
    was_js_on = (params[:was_js_on] == 'yes')

    # Create any reasons explicitly given.
    any_reasons = false
    for i in NamingReason.reasons
      if args && args[i.to_s]
        check = args[i.to_s][:check]
        notes = args[i.to_s][:notes]
        if check == '1' || !was_js_on && !notes.nil? && notes != ''
          reason = NamingReason.new(
            :naming => naming,
            :reason => i,
            :notes  => notes.nil? ? '' : notes
          )
          reason.save
          any_reasons = true
        end
      end
    end

    # If none given, create one or more default reasons.
    if !any_reasons
      for i in NamingReason.reasons
        reason = NamingReason.new(
          :naming => naming,
          :reason => i,
          :notes  => ''
        )
        reason.save if reason.default?
      end
    end
  end

  # Attempt to upload any images.  We will attach them to the observation
  # later, assuming we can create it.  Problem is if anything goes wrong, we
  # cannot repopulate the image forms (security issue associated with giving
  # file upload fields default values).  So we need to do this immediately,
  # even if observation creation fails.  Keep a list of images we've downloaded
  # successfully in @good_images (stored in hidden form field).
  #
  # INPUT: params[:image], observation, good_images (and @user)
  # OUTPUT: list of images we couldn't create
  def create_image_objects(args, observation, good_images)
    bad_images = []
    if args
      i = 0
      while args2 = args[i.to_s]
        if (upload = args2[:image]) && upload != ''
          name = upload.full_original_filename if upload.respond_to? :full_original_filename
          image = Image.new(args2)
          image.created = Time.now
          image.modified = image.created
          # If image.when is 1950 it means user never saw the form field, so we should use default instead.
          image.when = observation.when if image.when.year == 1950
          image.user = @user
          if !image.save || !image.save_image
            logger.error('Unable to upload image')
            flash_error("Had problems uploading image '#{name ? name : '???'}'.")
            bad_images.push(image)
            flash_object_errors(image)
          else
            flash_notice("Uploaded image " + (name ? "'#{name}'" : "##{image.id}") + '.')
            good_images.push(image)
            if observation.thumb_image_id == -i
              observation.thumb_image_id = image.id
            end
          end
        end
        i += 1
      end
    end
    if observation.thumb_image_id && observation.thumb_image_id.to_i <= 0
      observation.thumb_image_id = nil
    end
    return bad_images
  end

  # List of images that we've successfully downloaded, but which haven't been
  # attached to the observation yet.  Also supports some mininal editing.
  # INPUT: params[:good_images] (also looks at params[:image_<id>_notes])
  # OUTPUT: list of images
  def update_good_images(arg)
    # Get list of images first.
    images = (arg || '').split(' ').map do |id|
      Image.find(id.to_i)
    end

    # Now check for edits.
    for image in images
      notes = params["image_#{image.id}_notes"]
      if image.notes != notes
        image.notes = notes
        image.modified = Time.now
        image.save
        flash_notice("Updated notes on image ##{image.id}.")
      end
    end

    return images
  end

  # Now that the observation has been successfully created, we can attach
  # any images that were downloaded earlier
  def attach_good_images(observation, images)
    if images && images.length > 0
      for image in images
        if !observation.images.include?(image)
          observation.log("Image created by #{@user.login}: #{image.unique_format_name}", true)
          observation.add_image(image)
        end
      end
      observation.save
    end
  end

  # Initialize image for the dynamic image form at the bottom.
  def init_image(default_date)
    image = Image.new
    image.when             = default_date
    image.license          = @user.license
    image.copyright_holder = @user.legal_name
    return image
  end

  # Resolves the name using these heuristics:
  #   First time through:
  #     Only 'what' will be filled in.
  #     Prompts the user if not found.
  #     Gives user a list of options if matches more than one. ('names')
  #     Gives user a list of options if deprecated. ('valid_name')
  #   Second time through:
  #     'what' is a new string if user typed new name, else same as old 'what'
  #     'approved_name' is old 'what'
  #     'chosen_name' hash on name.id: radio buttons
  #     Uses the name chosen from the radio buttons first.
  #     If 'what' has changed, then go back to "First time through" above.
  #     Else 'what' has been approved, create it if necessary.
  #
  # INPUTS:
  #   what            params[:name][:name]            Text field.
  #   approved_name   params[:approved_name]          Last name user entered.
  #   chosen_name     params[:chosen_name][:name_id]  Name id from radio boxes.
  #   (@user -- might be used by one or more things)
  #
  # RETURNS:
  #   success       true: okay to use name; false: user needs to approve name.
  #   name          Name object if it resolved without reservations.
  #   names         List of choices if name matched multiple objects.
  #   valid_names   List of choices if name is deprecated.
  #
  def resolve_name(what, approved_name, chosen_name)
    success    = true
    name       = nil
    names      = nil
    valid_name = nil

    if !what.to_s.strip.empty? && !Name.names_for_unknown.member?(what.strip)
      success = false

      ignore_approved_name = false
      # Has user chosen among multiple matching names or among multiple approved names?
      if chosen_name
        names = [Name.find(chosen_name)]
        # This tells it to check if this name is deprecated below EVEN IF the user didn't change the what field.
        # This will solve the problem of multiple matching deprecated names discussed below.
        ignore_approved_name = true
      else
        # Look up name: can return zero (unrecognized), one (unambiguous match),
        # or many (multiple authors match).
        names = Name.find_names(what)
      end

      # Create temporary name object for it.  (This will not save anything
      # EXCEPT in the case of user supplying author for existing name that
      # has no author.)
      if names.length == 0
        names = [create_needed_names(approved_name, what, @user)]
      end

      target_name = names.first
      names = [] if !target_name
      if target_name && names.length == 1
        # Single matching name.  Check if it's deprecated.
        if target_name.deprecated and (ignore_approved_name or (approved_name != what))
          # User has not explicitly approved the deprecated name: get list of
          # valid synonyms.  Will display them for user to choose among.
          valid_names = target_name.approved_synonyms
        else
          # User has selected an unambiguous, accepted name... or they have
          # chosen or approved of their choice.  Either way, go with it.
          name = target_name
          # Fill in author, just in case user has chosen between two authors.
          # If the form fails for some other reason and we don't do this, it
          # will ask the user to choose between the authors *again* later.
          what = name.search_name
          # (This is the only way to get out of here with success.)
          success = true
        end
      elsif names.length > 1 && names.reject{|n| n.deprecated} == []
        # Multiple matches, all of which are deprecated.  Check if they all have
        # the same set of approved names.  Pain in the butt, but otherwise can
        # get stuck choosing between Helvella infula Fr. and H. infula Schaeff.
        # without anyone mentioning that both are deprecated by Gyromitra infula.
        valid_names = names.first.approved_synonyms.sort
        for n in names
          if n.approved_synonyms.sort != valid_names
            # If they have different sets of approved names (will this ever
            # actually happen outside my twisted imagination??!) then first have
            # the user choose among the deprecated names, THEN hopefully we'll
            # notice that their choice is deprecated and provide them with the
            # option of switching to one of the approved names.
            valid_names = []
            break
          end
        end
      end
    end

    return [success, what, name, names, valid_names]
  end

#--#############################################################################
#
#  These are for backwards compatibility.
#
#++#############################################################################

  def rewrite_url(obj, old_method, new_method)
    url = request.request_uri
    if url.match(/\?/)
      base = url.sub(/\?.*/, '')
      args = url.sub(/^[^?]*/, '')
    elsif url.match(/\/\d+$/)
      base = url.sub(/\/\d+$/, '')
      args = url.sub(/.*(\/\d+)$/, '\1')
    else
      base = url
      args = ''
    end
    base.sub!(/\/\w+\/\w+$/, '')
    return "#{base}/#{obj}/#{new_method}#{args}"
  end

  # Create redirection methods for all of the actions we've moved out
  # of this controller.  They just rewrite the URL, replacing the
  # controller with the new one (and optionally renaming the action).
  def self.action_has_moved(obj, old_method, new_method=nil)
    new_method = old_method if !new_method
    class_eval(<<-EOS)
      def #{old_method}
        redirect_to rewrite_url('#{obj}', '#{old_method}', '#{new_method}')
      end
    EOS
  end

  action_has_moved 'comment', 'list_comments'
  action_has_moved 'comment', 'show_comments_for_user'
  action_has_moved 'comment', 'show_comment'
  action_has_moved 'comment', 'add_comment'
  action_has_moved 'comment', 'edit_comment'
  action_has_moved 'comment', 'destroy_comment'

  action_has_moved 'name', 'all_names', 'name_index'
  action_has_moved 'name', 'name_index'
  action_has_moved 'name', 'observation_index'
  action_has_moved 'name', 'all_names'
  action_has_moved 'name', 'show_name'
  action_has_moved 'name', 'show_past_name'
  action_has_moved 'name', 'edit_name'
  action_has_moved 'name', 'change_synonyms'
  action_has_moved 'name', 'deprecate_name'
  action_has_moved 'name', 'approve_name'
  action_has_moved 'name', 'bulk_name_edit'
  action_has_moved 'name', 'map'
  action_has_moved 'name', 'cleanup_versions'
  action_has_moved 'name', 'do_maintenance'

  action_has_moved 'species_list', 'list_species_lists'
  action_has_moved 'species_list', 'show_species_list'
  action_has_moved 'species_list', 'species_lists_by_title'
  action_has_moved 'species_list', 'create_species_list'
  action_has_moved 'species_list', 'edit_species_list'
  action_has_moved 'species_list', 'upload_species_list'
  action_has_moved 'species_list', 'destroy_species_list'
  action_has_moved 'species_list', 'manage_species_lists'
  action_has_moved 'species_list', 'remove_observation_from_species_list'
  action_has_moved 'species_list', 'add_observation_to_species_list'

  action_has_moved 'image', 'list_images'
  action_has_moved 'image', 'images_by_title'
  action_has_moved 'image', 'show_image'
  action_has_moved 'image', 'show_original'
  action_has_moved 'image', 'next_image'
  action_has_moved 'image', 'prev_image'
  action_has_moved 'image', 'add_image'
  action_has_moved 'image', 'remove_images'
  action_has_moved 'image', 'edit_image'
  action_has_moved 'image', 'destroy_image'
  action_has_moved 'image', 'reuse_image'
  action_has_moved 'image', 'add_image_to_obs'
  action_has_moved 'image', 'reuse_image_by_id'
  action_has_moved 'image', 'license_updater'
  action_has_moved 'image', 'test_upload_image'
  action_has_moved 'image', 'test_add_image'
  action_has_moved 'image', 'test_add_image_report'
  action_has_moved 'image', 'resize_images'
end
