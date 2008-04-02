# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'find'
require 'ftools'

class ObserverController < ApplicationController
  before_filter :login_required, :except => (CSS + [:all_names,
                                                    :ask_webmaster_question,
                                                    :auto_complete_for_observation_place_name,
                                                    :auto_complete_for_name_name,
                                                    :color_themes,
                                                    :do_load_test,
                                                    :how_to_use,
                                                    :images_by_title,
                                                    :index,
                                                    :intro,
                                                    :list_comments,
                                                    :list_images,
                                                    :list_observations,
                                                    :list_rss_logs,
                                                    :list_species_lists,
                                                    :location_search,
                                                    :name_index,
                                                    :news,
                                                    :next_image,
                                                    :next_observation,
                                                    :observation_index,
                                                    :observation_search,
                                                    :observations_by_name,
                                                    :pattern_search,
                                                    :prev_image,
                                                    :prev_observation,
                                                    :recalc,
                                                    :rss,
                                                    :send_webmaster_question,
                                                    :show_comment,
                                                    :show_comments_for_user,
                                                    :show_image,
                                                    :show_location_observations,
                                                    :show_name,
                                                    :show_observation,
                                                    :show_original,
                                                    :show_past_name,
                                                    :show_rss_log,
                                                    :show_site_stats,
                                                    :show_species_list,
                                                    :show_user,
                                                    :show_user_observations,
                                                    :show_votes,
                                                    :species_lists_by_title,
                                                    :textilize_sandbox,
                                                    :throw_error,
                                                    :users_by_contribution])

  # Default page.  Just displays latest happenings.
  # View: list_rss_logs
  # Inputs: none
  # Outputs: none
  def index
    list_rss_logs
    render :action => 'list_rss_logs'
  end

  # Provided just as a way to verify the before_filter.
  # This page should always require the user to be logged in.
  # View: list_rss_logs
  # Inputs: none
  # Outputs: none
  def login
    list_rss_logs
    render :action => 'list_rss_logs'
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

  def textile_sandbox
    if request.method != :post
      @code = nil
    else
      @code = params[:code]
    end
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
    @user = session['user']
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

################################################################################
#
#  Observation support.
#
#  Views:
#    list_observations              All obvs, by date.
#    observations_by_name           All obvs, by name.
#    show_user_observations         User's obvs, by date.
#    show_location_observations     Obvs at a defined location, by name.
#    observation_search             Obvs that match a string.
#
#    recalc                         Debug: Recalcs consensus and renders show_obs.
#    show_observation
#    create_observation
#    edit_observation
#    destroy_observation
#    prev_observation
#    next_observation
#    auto_complete_for_observation_place_name
#
#  Helpers:
#    show_selected_observations(...)
#    create_observation_helper()
#
################################################################################

  def show_selected_observations(title, conditions, order, source, links=nil)
    # If provided, link should be the arguments for link_to as a list of lists,
    # e.g. [[:action => 'blah'], [:action => 'blah']]
    store_location
    @user = session['user']
    @layout = calc_layout_params
    @title = title
    @links = links
    conditions = "1=1" if !conditions || conditions == ""
    query = "select observations.id, names.search_name
      from observations, names
      left outer join locations on observations.location_id = locations.id
      where observations.name_id = names.id and (#{conditions})
      order by #{order}"
    session[:checklist_source] = source
    session[:observation_ids] = query_ids(query)
    session[:observation] = nil
    session[:image_ids] = nil
    @observation_pages, @observations = paginate(:observations,
      :include => [:name, :location],
      :order => order,
      :conditions => conditions,
      :per_page => @layout["count"])
    render :action => 'list_observations'
  end

  # Displays matrix of all observations, sorted by date.
  # Linked from: left-hand panel
  # Inputs: session['user']
  # Outputs: @observations, @observation_pages, @user, @layout
  def list_observations
    show_selected_observations("Observations", "", "observations.`when` desc", :all_observations)
  end

  # Displays matrix of all observations, alphabetically.
  # Linked from: nowhere
  # View: list_observations
  # Outputs: @observations, @observation_pages, @user, @layout
  def observations_by_name
    show_selected_observations("Observations", "",
      "names.search_name asc, observations.`when` desc", :all_observations)
  end

  # Displays matrix of user's observations, by date.
  # Linked from: left panel, show_user, users_by_contribution
  # View: list_observations
  # Inputs: params[:id] (user id)
  # Outputs: @observations, @observation_pages, @user, @layout
  def show_user_observations
    @user = User.find(params[:id])
    show_selected_observations("Observations by %s" % @user.legal_name,
      "observations.user_id = %s" % @user.id,
      "observations.modified desc, observations.`when` desc", :observation_ids)
  end

  # Searches for observations based on location, notes and consensus name
  # (including author).
  # Redirected from: pattern_search
  # View: list_observations
  # Inputs:
  #   session[:pattern]
  #   session['user']
  # Outputs: @observations, @observation_pages, @user, @layout
  def observation_search
    store_location
    @user = session['user']
    @layout = calc_layout_params
    @pattern = session[:pattern] || ''
    sql_pattern = "%#{@pattern.gsub(/[*']/,"%")}%"
    show_selected_observations("Observations matching '#{@pattern}'",
      field_search(["names.search_name", "observations.where",
        "observations.notes", "locations.display_name"], sql_pattern),
      "names.search_name asc, observations.`when` desc", :observation_ids)
  end

  # Displays matrix of observations at a location, alphabetically.
  # Linked from: show_location
  # View: list_observations
  # Inputs: params[:id] (location id)
  # Outputs: @observations, @observation_pages, @user, @layout
  def show_location_observations
    loc = Location.find(params[:id])
    show_selected_observations("Observations from %s" % loc.display_name,
      "observations.location_id = %s" % loc.id,
      "names.search_name, observations.`when` desc", :observation_ids,
      [[:location_show_map.l, {:controller => 'location', :action => 'show_location', :id => loc.id}]])
  end

  # Display matrix of observations whose location matches a string.
  # Redirected from: where_search
  # View: list_pbservations
  # Inputs: pattern
  # Outputs: @observations, @observation_pages, @user, @layout
  def location_search
    # Looks harder for pattern since location_controller.where_search was using :pattern for a bit
    # and some of the search monkeys picked up on it.
    pattern = session[:where] || session[:pattern] || ""
    sql_pattern = "%#{pattern.gsub(/[*']/,"%")}%"
    show_selected_observations("Observations from '#{pattern}'", "observations.where like '#{sql_pattern}'",
      "names.search_name asc, observations.`when` desc", :observation_ids,
      [[:location_define.l, {:controller => 'location', :action => 'create_location', :where => pattern}],
       [:location_merge.l, {:controller => 'location', :action => 'list_merge_options', :where => pattern}],
       [:location_all.l, {:controller => 'location', :action => 'list_place_names'}]])
  end

  # I'm tired of tweaking show_observation to call calc_consensus for debugging.
  # I'll just leave this stupid action in and have it forward to show_observation.
  def recalc
    id = params[:id]
    begin
      @observation = Observation.find(id)
      flash_notice "old_name: #{@observation.name.text_name}"
      text = @observation.calc_consensus
      flash_notice "new_name: #{@observation.name.text_name}"
      flash_notice text if !text.nil? && text != ""
    rescue
      flash_error "Caught exception."
    end
    redirect_to :action => "show_observation", :id => id
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
  # Inputs: params[:id], session['user']
  # Outputs:
  #   @observation, @user
  #   @confidence/agreement_menu    (used to create vote menus)
  #   @votes                        (user's vote for each naming.id)
  def show_observation
    store_location # Is this doing anything useful since there is no user check for this page?
    @observation = Observation.find(params[:id])
    session[:observation] = params[:id].to_i
    session[:image_ids] = nil
    @confidence_menu = translate_menu(Vote.confidence_menu)
    @agreement_menu  = translate_menu(Vote.agreement_menu)
    @votes = Hash.new
    @user = session['user']
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

  # Form to create a new observation, naming, and vote.
  # Linked from: left panel
  # Inputs (get):
  #   session['user']
  # Inputs (post):
  #   session['user']
  #   params[:observation][:where]      (Observation object)
  #   params[:observation][:specimen]
  #   params[:observation][:notes]
  #   params[:name][:name]              (to resolve name)
  #   params[:approved_name]
  #   params[:chosen_name][:name_id]
  #   params[:vote][:value]             (Vote object)
  #   params[:reason][n][:check]        (NamingReason object)
  #   params[:reason][n][:notes]
  # Outputs:
  #   @observation, @naming, @vote
  #   @what, @names, @valid_names
  #   @confidence_menu (used for vote option menu)
  #   @reason          (array of naming_reasons)
  def create_observation
    @user = session['user']
    if verify_user()
      # Clear search list.
      session[:observation_ids] = nil
      session[:observation]     = nil
      session[:image_ids]       = nil
      # Attempt to create observation (and associated naming, vote, etc.)
      if request.method == :post && create_observation_helper()
        redirect_to :action => 'show_observation', :id => @observation
      else
        # Create empty instances first time through.
        if request.method == :get
          @observation = Observation.new
          @naming      = Naming.new
          @vote        = Vote.new
          @what        = '' # can't be nil else rails tries to call @name.name
          @names       = nil
          @valid_names = nil
        end
        # Sets up some temp arrays needed by _form_naming.rhtml.
        form_naming_helper()
      end
    end
  end

  # Form to edit an existing observation.
  # Linked from: left panel
  # Inputs (get):
  #   session['user']
  #   params[:id] (observation)
  # Inputs (post):
  #   session['user']
  #   params[:id] (observation)
  #   params[:observation][:where]
  #   params[:observation][:specimen]
  #   params[:observation][:notes]
  #   params[:log_change][:checked]
  # Outputs:
  #   @observation
  def edit_observation
    @user = session['user']
    if verify_user()
      @observation = Observation.find(params[:id])
      if !check_user_id(@observation.user_id)
        redirect_to :action => 'show_observation', :id => @observation
      elsif request.method == :post &&
          @observation.update_attributes(params[:observation])
        @observation.modified = Time.now
        @observation.save
        @observation.log("Observation updated by #{@user.login}.",
          params[:log_change][:checked] == '1')
        flash_notice "Observation was successfully updated."
        redirect_to :action => 'show_observation', :id => @observation
      else
        session[:observation] = @observation.id
        flash_object_errors(@observation)
      end
    end
  end

  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation), session['user']
  # Redirects to list_observations.
  def destroy_observation
    @user = session['user']
    if verify_user()
      @observation = Observation.find(params[:id])
      if !check_user_id(@observation.user_id)
        flash_error "You do not own this observation."
        redirect_to :action => 'show_observation', :id => @observation
      else
        for spl in @observation.species_lists
          spl.log(sprintf('Observation, %s, destroyed by %s',
            @observation.unique_text_name, @user.login))
        end
        @observation.orphan_log("Observation destroyed by #{@user.login}")
        @observation.namings.clear # (takes votes with it)
        @observation.comments.clear
        @observation.destroy
        flash_notice "Successfully destroyed observation."
        redirect_to :action => 'list_observations'
      end
    end
  end

  # Go to previous observation in session[:observation_ids] (search results).
  # Linked from: show_observation
  # Inputs: params[:id] (observation), session[:observation_ids]
  # Redirects to show_observation.
  def prev_observation
    obs = session[:observation_ids]
    if obs
      index = obs.index(params[:id].to_i)
      if index.nil? or obs.nil? or obs.length == 0
        index = 0
      else
        index = index - 1
        if index < 0
          index = obs.length - 1
        end
      end
      id = obs[index]
      redirect_to(:action => 'show_observation', :id => id)
    else
      redirect_to(:action => 'list_rss_logs')
    end
  end

  # Go to previous observation in session[:observation_ids] (search results).
  # Linked from: show_observation
  # Inputs: params[:id] (observation), session[:observation_ids]
  # Redirects to show_observation.
  def next_observation
    obs = session[:observation_ids]
    if obs
      index = obs.index(params[:id].to_i)
      if index.nil? or obs.nil? or obs.length == 0
        index = 0
      else
        index = index + 1
        if index >= obs.length
          index = 0
        end
      end
      id = obs[index]
      redirect_to(:action => 'show_observation', :id => id)
    else
      redirect_to(:action => 'list_rss_logs')
    end
  end

  # AJAX request used for autocompletion of "where" field in _form_observation.
  # View: none
  # Inputs: params[:observation][:place_name]
  # Outputs: none
  def auto_complete_for_observation_place_name
    auto_complete_location(:observation, :place_name)
  end

################################################################################
#
#  Naming support.
#
#  Views:
#    create_naming
#    edit_naming
#    destroy_naming
#    auto_complete_for_name_name
#
#  Helpers:
#    create_naming_helper()
#    edit_naming_helper()
#    form_naming_helper()
#    resolve_name_helper()
#    create_naming_reasons_helper(naming)
#
################################################################################

  # Form to propose new naming for an observation.
  # Linked from: show_observation
  # Inputs (get):
  #   session['user']
  #   params[:id] (observation)
  # Inputs (post):
  #   session['user']
  #   params[:id] (observation)
  #   params[:name][:name]              (to resolve name)
  #   params[:approved_name]
  #   params[:chosen_name][:name_id]
  #   params[:vote][:value]             (Vote object)
  #   params[:reason][n][:check]        (NamingReason object)
  #   params[:reason][n][:notes]
  # Outputs:
  #   @observation, @naming, @vote
  #   @what, @names, @valid_names
  #   @confidence_menu (used for vote option menu)
  #   @reason          (array of naming_reasons)
  def create_naming
    @user = session['user']
    if verify_user()
      @observation = Observation.find(params[:id])
      # Attempt to create naming (and associated vote, etc.)
      if request.method == :post && create_naming_helper()
        redirect_to :action => 'show_observation', :id => @observation
      else
        # Create empty instances first time through.
        if request.method == :get
          @naming      = Naming.new
          @vote        = Vote.new
          @what        = '' # can't be nil else rails tries to call @name.name
          @names       = nil
          @valid_names = nil
        end
        # Sets up some temp arrays needed by _form_naming.rhtml.
        form_naming_helper()
      end
    end
  end

  # Form to edit an existing naming for an observation.
  # Linked from: show_observation
  # Inputs (get):
  #   session['user']
  #   params[:id] (naming)
  # Inputs (post):
  #   session['user']
  #   params[:id] (naming)
  #   params[:name][:name]              (to resolve name)
  #   params[:approved_name]
  #   params[:chosen_name][:name_id]
  #   params[:vote][:value]             (Vote object)
  #   params[:reason][n][:check]        (NamingReason object)
  #   params[:reason][n][:notes]
  # Outputs:
  #   @observation, @naming, @vote
  #   @what, @names, @valid_names
  #   @confidence_menu (used for vote option menu)
  #   @reason          (array of naming_reasons)
  def edit_naming
    @user = session['user']
    if verify_user()
      @naming = Naming.find(params[:id])
      if @naming
        @observation = @naming.observation
        @vote = Vote.find(:first, :conditions =>
          ['naming_id = ? AND user_id = ?', @naming.id, @naming.user_id])
      end
      if !check_user_id(@naming.user_id)
        redirect_to :action => 'show_observation', :id => @observation
      # Attempt to update naming (and associated vote, etc.)
      elsif request.method == :post && edit_naming_helper()
        redirect_to :action => 'show_observation', :id => @observation
      else
        # Initialize the "what" field.
        if request.method == :get
          @what        = @naming.text_name
          @names       = nil
          @valid_names = nil
        end
        # Sets up some temp arrays needed by _form_naming.rhtml.
        form_naming_helper()
      end
    end
  end

  # Callback to destroy a naming (and associated votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation), session['user']
  # Redirects back to show_observation.
  def destroy_naming
    @user = session['user']
    @naming = Naming.find(params[:id])
    @observation = @naming.observation
    if !check_user_id(@naming.user_id)
      flash_error "You do not own that naming."
      redirect_to :action => 'show_observation', :id => @observation
    elsif !@naming.deletable?
      flash_warning "Sorry, someone else has given this their strongest
        positive vote.  You are free to propose alternate names,
        but we can no longer let you delete this name."
      redirect_to :action => 'show_observation', :id => @observation
    else
      @naming.observation.log("Naming deleted by #{@user.login}: #{@naming.format_name}", true)
      @naming.votes.clear
      @naming.destroy
      @observation.calc_consensus
      flash_notice "Successfully destroyed naming."
      redirect_to :action => 'show_observation', :id => @observation
    end
  end

  # AJAX request used for autocompletion of "what" field in _form_naming.
  # View: none
  # Inputs: params[:name][:name]
  # Outputs: none
  def auto_complete_for_name_name
    auto_complete_name(:name, :name)
  end

################################################################################

  def create_observation_helper()
    # Roughly create and populate observation, naming, and vote instances.
    # Don't save them until we're sure everything is right.
    now = Time.now
    @user = session['user']
    @observation = Observation.new(params[:observation])
    @observation.created  = now
    @observation.modified = now
    @observation.user     = @user
    @naming = Naming.new(params[:naming])
    @naming.created     = now
    @naming.modified    = now
    @naming.user        = @user
    @naming.observation = @observation
    @vote = Vote.new(params[:vote])
    @vote.created  = now
    @vote.modified = now
    @vote.user     = @user
    @vote.naming   = @naming
    #
    # Resolve chosen name (see resolve_name_helper for full heuristics).
    # I'm allowing user to create observations without a naming for now.
    @what = params[:name][:name]
    if !@what || Name.names_for_unknown.member?(@what.strip)
      @name = nil
    else
      @name = resolve_name_helper()
      return false if !@name
      @naming.name = @name
    end
    #
    # Do some simple validation before saving stuff.  (Name(s) might have
    # already been saved, but there's nothing we can do about that.  If we
    # put this above resolve_name_helper(), then it will approve names
    # silently, and that's even worse that silently creating names before
    # the user has correctly completed the form.)
    if !@observation.valid?
      flash_object_errors(@observation)
      return false
    elsif @name && !@naming.valid?
      flash_object_errors(@naming)
      return false
    elsif @name && !@vote.valid?
      flash_object_errors(@vote)
      return false
    end
    #
    # Now if the user has named it, finish creating the naming
    # (create_naming_reasons_helper creates all the NamingReason objects tied
    # to the Naming).
    if @name
      create_naming_reasons_helper(@naming)
    else
      @observation.name = Name.unknown
    end
    #
    # Finally, save everything.
    if !@observation.save
        flash_object_errors(@observation)
        return false
    end
    #
    # Beyond this point errors are non-fatal.
    errors = []
    if @name
      if !@naming.save
        errors << "Unable to save the naming."
      end
      @observation.namings.push(@naming)
      # Update vote and community consensus.
      @naming.change_vote(@user, @vote.value)
    end
    if errors != []
      errors.unshift("Observation was created, however had
        trouble with the following:")
      flash_warning errors.join("<br/>")
      flash_object_warnings(@naming)
      flash_object_warnings(@vote)
      flash_object_warnings(@observation)
    else
      flash_notice "Observation was successfully created."
    end
    #
    # Log actions.
    @observation.log("Observation created by #{@user.login}.", true)
    return true
  end

  def create_naming_helper()
    # Get this immediately so it will retain whatever name user typed in
    # in case we encounter errors before we validate name.
    @what = params[:name][:name] if params[:name]
    #
    # Roughly create and populate naming and vote instances.
    # Don't save them until we're sure everything is right.
    now = Time.now
    @user = session['user']
    @naming = Naming.new(params[:naming])
    @naming.created     = now
    @naming.modified    = now
    @naming.user        = @user
    @naming.observation = @observation
    @vote = Vote.new(params[:vote])
    @vote.created  = now
    @vote.modified = now
    @vote.user     = @user
    @vote.naming   = @naming
    #
    # Resolve chosen name (see resolve_name_helper for full heuristics).
    @name = resolve_name_helper()
    return false if !@name
    if @observation.name_been_proposed?(@name)
      flash_warning "Someone has already proposed that name.  If you would
                     like to comment on it, try posting a comment instead."
      return false
    end
    @naming.name = @name
    if !@naming.valid?
      flash_object_errors(@naming)
      return false
    end
    #
    # Do some simple validation before saving stuff.  (Name(s) might have
    # already been saved, but there's nothing we can do about that.  If we
    # put this above resolve_name_helper(), then it will approve names
    # silently, and that's even worse that silently creating names before
    # the user has correctly completed the form.)
    if !@vote.valid?
      flash_object_errors(@vote)
      return false
    end
    #
    # Now finish creating the naming (create_naming_reasons_helper creates all
    # the NamingReason objects tied to the Naming).
    create_naming_reasons_helper(@naming)
    #
    # Finally, save everything.
    if !@naming.save
      flash_object_errors(@naming)
      return false
    else
      flash_notice "Naming was successfully created."
    end
    @observation.namings.push(@naming)
    #
    # Update vote and community consensus.
    @naming.change_vote(@user, @vote.value)
    #
    # Log actions.
    @observation.log("Naming created by #{@user.login}: #{@naming.format_name}", true)
    return true
  end

  def edit_naming_helper()
    now = Time.now
    @user = session['user']
    #
    # Resolve chosen name (see resolve_name_helper for full heuristics).
    @what = params[:name][:name] if params[:name]
    @name = resolve_name_helper()
    return false if !@name
    if @naming.name != @name && @observation.name_been_proposed?(@name)
      flash_warning "Someone has already proposed that name.  If you would
                     like to comment on it, try posting a comment instead."
      return false
    end
    #
    # Owner is not allowed to change a naming once it's been used by someone
    # else.  Instead I automatically clone it and make changes to the clone.
    # I assume there will be no validation problems since we're cloning
    # pre-existing valid objects.
    if !@naming.editable? && @name.id != @naming.name_id
      @naming = Naming.new(params[:naming])
      @naming.created     = now
      @naming.modified    = now
      @naming.user        = @user
      @naming.observation = @observation
      @naming.name        = @name
      @vote = Vote.new(params[:vote])
      @vote.created  = now
      @vote.modified = now
      @vote.user     = @user
      @vote.naming   = @naming
      #
      # Finish creating the naming (create_naming_reasons_helper creates all
      # the NamingReason objects tied to the Naming).
      create_naming_reasons_helper(@naming)
      #
      # Now save everything.
      flash_warning "Sorry, someone else has given this a positive vote,
        so we had to create a new Naming to accomodate your changes."
      if !@naming.save
        flash_warning "However we were unable to create the new naming."
        flash_object_warnings(@naming)
        return false
      end
      @observation.namings.push(@naming)
      #
      # Update community consensus.
      @naming.change_vote(@user, @vote.value);
      #
      # Log action.
      @observation.log("Naming created by #{@user.login}: #{@naming.format_name}", true)
      return true
    #
    # Owner is allowed to change the naming so long as no one else has used it.
    # They are also allowed to change the reasons even if others have used it.
    else
      # If user's changed the name, it sorta invalidates any votes that others
      # might have cast prior to this.
      need_to_calc_consensus = false
      need_to_log_change = false
      if @name.id != @naming.name_id
        for vote in @naming.votes
          vote.destroy if vote.user_id != @user.id
        end
        need_to_calc_consensus = true
        need_to_log_change = true
      end
      #
      # Update naming (even if nothing has actually changed, I'm lazy).
      @naming.modified = now
      @naming.name = @name
      @naming.naming_reasons.clear
      create_naming_reasons_helper(@naming)
      @naming.save
      #
      # Only change vote if changed value.
      if params[:vote] && (!@vote || @vote.value != params[:vote][:value].to_i)
        @naming.change_vote(@user, params[:vote][:value].to_i)
        need_to_calc_consensus = false
      end
      @observation.calc_consensus if need_to_calc_consensus
      #
      # Log actions.
      @observation.log("Naming changed by #{@user.login}: #{@naming.format_name}", need_to_log_change)
      flash_notice "Naming was successfully updated."
      return true
    end
  end

  # Gets some constants from the models needed by the _form_naming view.
  def form_naming_helper()
    reason_args = params[:reason]
    @confidence_menu = translate_menu(Vote.confidence_menu)
    #
    # reason_args is passed back from construct/update_observation/naming
    # if it's not present then take defaults from the existing @naming
    @reason = {}
    if reason_args
      for i in NamingReason.reasons
        check = reason_args[i.to_s][:check]
        notes = reason_args[i.to_s][:notes]
        if check == "1" && notes.nil?
          notes = ""
        elsif check == "0" && notes == ""
          notes = nil
        end
        @reason[i] = NamingReason.new(:reason => i, :notes => notes)
      end
    elsif @naming
      for r in @naming.naming_reasons
        @reason[r.reason] = r
      end
      for i in NamingReason.reasons
        if !@reason.has_key?(i)
          @reason[i] = NamingReason.new(:reason => i, :notes => nil)
        end
      end
    end
  end

  # Resolves the name using these heuristics:
  #   First time through:
  #     Only @what is set.
  #     Prompts the user if not found.
  #     Gives user a list of options if matches more than one.
  #       (passes them in via @names)
  #     Gives user a list of options if deprecated.
  #       (passes them in via @valid_name)
  #   Second time through:
  #     @what = new string if user typed new name, else same as old @what
  #     params[:approved_name] = old @what
  #     params[:chosen_name] = name.id of radio button (default is zero?)
  #     Uses the name chosen from the radio buttons first.
  #     If @what has changed, then go back to "First time through" above.
  #     Else creates name and uses it if @what doesn't exist.
  #     Otherwise @what must be deprecated: use it anyway.
  # NOTE:
  #   requires @user and @what to be set
  #   uses params[:approved_name] and params[:chosen_name]
  #   sets @names, @valid_names
  def resolve_name_helper()
    ignore_approved_name = false
    if params[:chosen_name] && params[:chosen_name][:name_id]
      # User has chosen among multiple matching names or among multiple approved names.
      @names = [Name.find(params[:chosen_name][:name_id])]
      # This tells it to check if this name is deprecated below EVEN IF the user didn't change the what field.
      # This will solve the problem of multiple matching deprecated names discussed below.
      ignore_approved_name = true
    else
      # Look up name: can return zero to many matches.
      @names = Name.find_names(@what)
      logger.warn("resolve_name_helper: #{@names.length}")
    end
    if @names.length == 0
      # Create temporary name object for it.  (This will not save anything
      # EXCEPT in the case of user supplying author for existing name that
      # has no author.)
      @names = [create_needed_names(params[:approved_name], @what, @user)]
    end
    target_name = @names.first
    @names = [] if !target_name
    if target_name && @names.length == 1
      # Single matching name.  Check if it's deprecated.
      if target_name.deprecated and (ignore_approved_name or (params[:approved_name] != @what))
        # User has not explicitly approved the deprecated name: get list of
        # valid synonyms.  Will display them for user to choose among.
        @valid_names = target_name.approved_synonyms
      else
        # User has approved a deprecated name.  Go with it.
        return target_name
      end
    elsif @names.length > 1 && @names.reject{|n| n.deprecated} == []
      # Multiple matches, all of which are deprecated.  Check if they all have
      # the same set of approved names.  Pain in the butt, but otherwise can
      # get stuck choosing between Helvella infula Fr. and H. infula Schaeff.
      # without anyone mentioning that both are deprecated by Gyromitra infula. 
      @valid_names = @names.first.approved_synonyms.sort
      for n in @names
        if n.approved_synonyms.sort != @valid_names
          # If they have different sets of approved names (will this ever
          # actually happen outside my twisted imagination??!) then first have
          # the user choose among the deprecated names, THEN hopefully we'll
          # notice that their choice is deprecated and provide them with the
          # option of switching to one of the approved names.
          @valid_names = []
          break
        end
      end
    end
    return nil
  end

  # Creates all the reasons for a naming.
  # Gets checkboxes and notes from params[:reason].
  # MUST BE CLEARED before calling this!
  def create_naming_reasons_helper(naming)
    any_reasons = false
    for i in NamingReason.reasons
      if params[:reason] && params[:reason][i.to_s] # (this obviates the need to create reasons in test suite)
        check = params[:reason][i.to_s][:check]
        notes = params[:reason][i.to_s][:notes]
        if check == "1" || !notes.nil? && notes != ""
          reason = NamingReason.new(
            :naming => naming,
            :reason => i,
            :notes  => notes.nil? ? "" : notes
          )
          reason.save
          any_reasons = true
        end
      end
    end
    if !any_reasons
      for i in NamingReason.reasons
        reason = NamingReason.new(
          :naming => naming,
          :reason => i,
          :notes  => ""
        )
        reason.save if reason.default?
      end
    end
  end

################################################################################
#
#  Vote support.
#
#  Views:
#    cast_vote
#    show_votes
#
################################################################################

  # Create vote if none exists; change vote if exists; delete vote if setting
  # value to -1 (owner of naming is not allowed to do this).
  # Linked from: show_observation
  # Inputs: params[], session['user']
  # Redirects to show_observation.
  def cast_vote
    user = session['user']
    if verify_user()
      if !params[:vote] || !params[:vote][:value]
        raise "Invoked cast_vote without any parameters!"
      else
        naming = Naming.find(params[:vote][:naming_id])
        value = params[:vote][:value].to_i
        naming.change_vote(user, value)
        redirect_to :action => 'show_observation', :id => naming.observation
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
    redirect_to :action => 'index'
  end

################################################################################
#
#  User support.
#
#    users_by_name
#    users_by_contribution
#    show_user
#    show_site_stats
#
################################################################################

  # users_by_name.rhtml
  # Restricted to the admin user
  def users_by_name
    if check_permission(0)
      @users = User.find(:all, :order => "'last_login' desc")
    else
      redirect_to :action => 'list_observations'
    end
  end

  # users_by_contribution.rhtml
  def users_by_contribution
    @user_ranking = SiteData.new.get_user_ranking
  end

  # show_user.rhtml
  def show_user
    store_location
    id = params[:id]
    @user = User.find(id)
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

################################################################################
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
################################################################################

  def ask_webmaster_question
    @user = session['user']
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
      @users = User.find(:all, :conditions => "feature_email=1")
    else
      redirect_to :action => 'list_observations'
    end
  end

  def send_feature_email
    if check_permission(0)
      users = User.find(:all, :conditions => "feature_email=1")
      for user in users
        AccountMailer.deliver_email_features(user, params['feature_email']['content'])
      end
      flash_notice "Delivered feature mail."
      redirect_to :action => 'users_by_name'
    else
      flash_error "Only the admin can send feature mail."
      redirect_to :action => "list_rss_logs"
    end
  end

  def email_question(user, target_page, target_obj)
    if !user.question_email
      flash_error "Permission denied"
      redirect_to :action => target_page, :id => target_obj
    end
  end

  def ask_user_question
    @user = User.find(params[:id])
    email_question(@user, 'show_user', @user)
  end

  def send_user_question
    sender = session['user']
    user = User.find(params[:id])
    subject = params[:email][:subject]
    content = params[:email][:content]
    AccountMailer.deliver_user_question(sender, user, subject, content)
    flash_notice "Delivered email."
    redirect_to :action => 'show_user', :id => user
  end

  def ask_observation_question
    @observation = Observation.find(params[:id])
    email_question(@observation.user, 'show_observation', @observation)
  end

  def send_observation_question
    sender = session['user']
    observation = Observation.find(params[:id])
    question = params[:question][:content]
    AccountMailer.deliver_observation_question(sender, observation, question)
    flash_notice "Delivered question."
    redirect_to :action => 'show_observation', :id => observation
  end

  def commercial_inquiry
    @image = Image.find(params[:id])
    @user = session['user']
    if !@image.user.commercial_email
      flash_error "Permission denied."
      redirect_to :action => 'show_image', :id => @image
    end
  end

  def send_commercial_inquiry
    sender = session['user']
    image = Image.find(params[:id])
    commercial_inquiry = params[:commercial_inquiry][:content]
    AccountMailer.deliver_commercial_inquiry(sender, image, commercial_inquiry)
    flash_notice "Delivered commercial inquiry."
    redirect_to :action => 'show_image', :id => image
  end

################################################################################
#
#  RSS support.
#
#  Views:
#    rss
#    list_rss_logs
#    show_rss_log
#
################################################################################

  def rss
    headers["Content-Type"] = "application/xml"
    @logs = RssLog.find(:all, :order => "'modified' desc",
                        :conditions => "datediff(now(), modified) <= 31",
                        :limit => 100)
    render :action => "rss", :layout => false
  end

  # left-hand panel -> list_rss_logs.rhtml
  def list_rss_logs
    store_location
    @user = session['user']
    @layout = calc_layout_params
    session[:checklist_source] = :all_observations
    query = "select observation_id as id, modified from rss_logs where observation_id is not null and " +
            "modified is not null order by 'modified' desc"
    session[:observation_ids] = query_ids(query)
    session[:observation] = nil
    session[:image_ids] = nil
    @rss_log_pages, @rss_logs = paginate(:rss_log,
                                         :order => "'modified' desc",
                                         :per_page => @layout["count"])
  end

  def show_rss_log
    store_location
    @user = session['user']
    @rss_log = RssLog.find(params['id'])
  end

################################################################################
#
#  These are for backwards compatibility.
#
################################################################################

  def rewrite_url(obj, old_method, new_method)
    url = request.request_uri
    if url.match(/\?/)
      base = url.sub(/\?.*/, "")
      args = url.sub(/^[^?]*/, "")
    elsif url.match(/\/\d+$/)
      base = url.sub(/\/\d+$/, "")
      args = url.sub(/.*(\/\d+)$/, '\1')
    else
      base = url
      args = ""
    end
    base.sub!(/\/\w+\/\w+$/, "")
    return "#{base}/#{obj}/#{new_method}#{args}"
  end

  # Create redirection methods for all of the actions we've moved out
  # of this controller.  They just rewrite the URL, replacing the
  # controller with the new one (and optionally renaming the action).
  def self.action_has_moved(obj, old_method, new_method=nil)
    new_method = old_method if !new_method
    class_eval(<<-EOS)
      def #{old_method}
        redirect_to_url rewrite_url('#{obj}', '#{old_method}', '#{new_method}')
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
