# Copyright (c) 2008 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

################################################################################
#
#  NOTE: There is some ambiguity between observations and names that makes this
#  slightly confusing.  The end result of a species list is actually a list of
#  *observations*, not species.  However, creation and editing is generally
#  accomplished via names alone (although see manage_species_lists for the one
#  exception).  In the end all these names cause rudimentary observations to
#  spring into existence.
#
#  Views:
#    list_species_lists                     List of lists by date.
#    species_lists_by_title                 List of lists by title.
#    show_species_list                      Display notes/etc. and list of species.
#    create_species_list                    Create new list.
#    edit_species_list                      Edit existing list.
#    upload_species_list                    Same as edit_species_list but gets list from file.
#    destroy_species_list                   Destroy list.
#    manage_species_lists                   Add/remove an observation from a user's lists.
#    remove_observation_from_species_list   (post method)
#    add_observation_to_species_list        (post method)
#
#  Helpers:
#    calc_checklist(id)                   Get list of names for LHS of _species_list_form.
#    sort_species_list_observations(...)  Get list of observations for show_species_list.
#    get_list_of_deprecated_names(spl)    Get list of names from list that are deprecated.
#    process_species_list(...)            Create/update species list using form data.
#    construct_observations(...)          Create observations for new names added to list.
#    find_chosen_name(id, alternatives)   (helper)
#
################################################################################

class SpeciesListController < ApplicationController
  before_filter :login_required, :except => [
    :list_species_lists,
    :show_species_list,
    :species_lists_by_title,
    :auto_complete_for_species_list_where
  ]

  # Display list of all species_lists, sorted by date.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs: @species_lists, @species_list_pages
  def list_species_lists
    store_location
    session_setup
    @species_list_pages, @species_lists = paginate(:species_lists,
                                                   :order => "'when' desc, 'id' desc",
                                                   :per_page => 10)
  end

  # Linked from: list_species_lists, show_observation, create/edit_species_list, etc. etc.
  # Inputs: params[:id] (species_list), session['user']
  # Outputs: @species_list, @observation_list, @user
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list
    store_location
    @user = session['user']
    id = params[:id]
    @search_seq = calc_search(:species_list_observations, "s.id = %s" % id, "n.search_name").key
    @species_list = SpeciesList.find(id)
    session[:species_list] = @species_list
    if session[:checklist_source] != id
      session[:prev_checklist_source] = session[:checklist_source]
      session[:checklist_source] = id
    end
    @observation_list = sort_species_list_observations(@species_list, @user)
  end

  # Sort observations in species_list and return list of observation objects.
  # Needed by everyone using the show_species_list view.
  def sort_species_list_observations(spl, user)
    if spl.observations.length > 0
      names = {}
      # I've changed this around so we only have to do the expensive
      # preferred_name(user) lookup once for each observation.  Then
      # we can sort based on the cached results. -JPH 20071205
      for o in spl.observations
        names[o] = o.preferred_name(user)
      end
      objects = names.keys.sort {|x,y|
        (names[x].text_name <=> names[y].text_name) || (x.id <=> y.id)
      }
      return objects
    else
      return nil
    end
  end

  # Display list of all species_lists, sorted by title.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs: @species_lists
  def species_lists_by_title
    session_setup
    store_location
    @species_lists = SpeciesList.find(:all, :order => "'title' asc, 'when' desc")
  end

  # AJAX request used for autocompletion of "where" field in _form_species_list.
  # View: none
  # Inputs: params[:species_list][:where]
  # Outputs: none
  def auto_complete_for_species_list_where
    auto_complete_location(:species_list, :where)
  end

  # Form for creating a new species list.
  # Linked from: left-hand panel
  # Inputs:
  #   session['user']
  # Outputs:
  #   @user
  #   @checklist_names
  #   @species_list
  #   @list_members
  #   @new_names
  #   @multiple_names
  #   @deprecated_names
  #   @member_notes
  #   session[:checklist]
  def create_species_list
    @user = session['user']
    @species_list = SpeciesList.new
    if verify_user()
      if request.method == :get
        @checklist_names  = {}
        @list_members     = nil
        @new_names        = nil
        @multiple_names   = nil
        @deprecated_names = nil
        @member_notes     = nil
        calc_checklist(nil)
      else
        process_species_list('created')
      end
    end
  end

  # Form to edit species list.
  # Linked from: show/upload_species_list
  # Inputs:
  #   params[:id] (species_list)
  #   session['user']
  # Outputs:
  #   @user
  #   @checklist_names
  #   @species_list
  #   @list_members
  #   @new_names
  #   @multiple_names
  #   @deprecated_names
  #   @member_notes
  #   session[:checklist]
  def edit_species_list
    @user = session['user']
    @species_list = SpeciesList.find(params[:id])
    if verify_user()
      if !check_user_id(@species_list.user_id)
        @observation_list = sort_species_list_observations(@species_list, @user)
        render :action => 'show_species_list'
      elsif request.method == :get
        @checklist_names  = {}
        @list_members     = nil
        @new_names        = nil
        @multiple_names   = nil
        @member_notes     = nil
        @deprecated_names = get_list_of_deprecated_names(@species_list)
        calc_checklist(params[:id])
      else
        process_species_list('updated')
      end
    end
  end

  # Post method for create/edit_species_list.  Creates/changes the
  # species_list object, doing highly sophisticated validation and stuff
  # on the list of names.  Uses construct_observations() to create the actual
  # observations, which in turn uses species_list.construct_observation().
  # Inputs:
  #   type_str                  (used for diagnostic in construct_observations)
  #   @user, @species_list
  #   params[:species_list][:when]
  #   params[:species_list][:where]
  #   params[:species_list][:title]
  #   params[:species_list][:notes]
  #   params[:member][:notes]               
  #   params[:list][:members]               String that user typed in in big text area on right side (squozen and stripped).
  #   params[:approved_names]               List of new names from prev post.
  #   params[:approved_deprecated_names]    List of deprecated names from prev post.
  #   params[:chosen_names][name]           Radio boxes disambiguating multiple names
  #   params[:chosen_approved_names][name]  Radio boxes allowing user to choose preferred names for deprecated ones.
  #     (Both the last two radio boxes are hashes with:
  #       key: ambiguous name as typed with nonalphas changed to underscores,
  #       val: id of name user has chosen (via radio boxes in feedback)
  #   params[:checklist_data][...]          Radio boxes on left side: hash from name id to "checked".
  #   params[:checklist_names][name_id]     (Used by view to give a name to each id in checklist_data hash.)
  # Success: redirects to show_species_list
  # Failure: redirects back to create_edit_species_list.
  def process_species_list(type_str)
    args = params[:species_list]
    #
    # Update the timestamps/user/when/where/title/notes fields.
    now = Time.now
    @species_list.created  = now if type_str == "created"
    @species_list.modified = now
    @species_list.user     = @user
    @species_list.attributes = args
    #
    # This just makes sure all the names (that have been approved) exist.
    list = params[:list][:members].squeeze(" ") # Get rid of extra whitespace while we're at it
    construct_approved_names(list, params[:approved_names], @user)
    #
    # Sets up a NameSorter object.  Does NOT affect species_list.
    sorter = setup_sorter(params, @species_list, list)
    #
    # Now see if we can successfully create the list...
    if sorter.has_new_synonyms
      flash_error "Synonyms can only be created from the Bulk Name Edit page."
      sorter.reset_new_names
    elsif sorter.only_single_names
      if sorter.has_unapproved_deprecated_names
        # This error message is unnecessary.
        # flash_error "Found deprecated names."
      # Okay, at this point we've apparently validated the new list of names.
      # Save the OTHER changes to the species list, then let this other
      # method (construct_observations) update the members.  This always
      # succeeds, so we can redirect to show_species_list.
      elsif @species_list.save
        construct_observations(@species_list, params, type_str, @user, sorter)
        redirect_to :action => 'show_species_list', :id => @species_list
        return
      else
        flash_object_errors(@species_list)
      end
    elsif sorter.new_name_strs != []
      # This is also now unnecessary.
      # flash_error "Unrecognized names including '#{sorter.new_name_strs[0]}' given."
    else
      # This is also now unnecessary.
      # flash_error "Ambiguous names including '#{sorter.multiple_line_strs[0]}' given."
    end
    #
    # Failed to create due to synonyms, unrecognized names, etc.
    @list_members     = sorter.all_line_strs.join("\r\n")
    @new_names        = sorter.new_name_strs.uniq.sort
    @multiple_names   = sorter.multiple_line_strs.uniq.sort
    @deprecated_names = sorter.deprecated_name_strs.uniq.sort
    @checklist_names  = params[:checklist_data] || {}
    @member_notes     = params[:member] ? params[:member][:notes] : ""
  end

  # Form to let user create/edit species_list from file.
  # Linked from: edit_species_list
  # Inputs: params[:id] (species_list), session['user']
  #   params[:species_list][:file]
  # Get: @species_list, @user
  # Post: goes to edit_species_list
  def upload_species_list
    @user = session['user']
    @species_list = SpeciesList.find(params[:id])
    if verify_user()
      if !check_user_id(@species_list.user_id)
        @observation_list = sort_species_list_observations(@species_list, @user)
        render :action => 'show_species_list'
      elsif request.method == :get
        @observation_list = sort_species_list_observations(@species_list, @user)
      else
        file_data = params[:species_list][:file]
        @species_list.file = file_data
        sorter = NameSorter.new
        @species_list.process_file_data(sorter)
        @list_members     = sorter.all_line_strs.join("\r\n")
        @new_names        = sorter.new_name_strs.uniq.sort
        @multiple_names   = sorter.multiple_line_strs.uniq.sort
        @deprecated_names = sorter.deprecated_name_strs.uniq.sort
        @checklist_names  = {}
        @member_notes     = ''
        # Is there a better way to give unit test access to @list_members???
        flash[:list_members] = @list_members
        render :action => 'edit_species_list'
      end
    end
  end

  # Callback to destroy a list.
  # Linked from: show_species_list
  # Inputs: params[:id] (species_list), session['user']
  # Redirects to list_species_lists.
  def destroy_species_list
    @user = session['user']
    @species_list = SpeciesList.find(params[:id])
    if check_user_id(@species_list.user_id)
      @species_list.orphan_log('Species list destroyed by ' + @user.login)
      @species_list.destroy
      flash_notice "Species list destroyed."
      redirect_to :action => 'list_species_lists'
    else
      @observation_list = sort_species_list_observations(@species_list, @user)
      render :action => 'show_species_list'
    end
  end

  # Form to let user add/remove an observation from his various lists.
  # Linked from: show_observation
  # Inputs: params[:id] (observation), session['user']
  # Outputs: @observation, @user
  def manage_species_lists
    if verify_user()
      @user = session['user']
      @observation = Observation.find(params[:id])
    end
  end

  # Remove an observation from a species_list.
  # Linked from: manage_species_lists
  # Inputs:
  #   params[:species_list]
  #   params[:observation]
  # Redirects back to manage_species_lists.
  def remove_observation_from_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations.delete(observation)
      flash_notice "Removed from #{species_list.unique_text_name}."
      redirect_to(:action => 'manage_species_lists', :id => observation)
    else
      redirect_to(:action => 'show_species_list', :id => species_list)
    end
  end

  # Add an observation to a species_list.
  # Linked from: manage_species_lists
  # Inputs:
  #   params[:species_list]
  #   params[:observation]
  # Redirects back to manage_species_lists.
  def add_observation_to_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_user_id(species_list.user_id)
      observation = Observation.find(params[:observation])
      species_list.modified = Time.now
      species_list.observations << observation
      flash_notice "Added to #{species_list.unique_text_name}."
      redirect_to :action => 'manage_species_lists', :id => observation
    end
  end

################################################################################

  # This appears to be called only by create/edit_species_list.
  # In the former case (create) it is called with nil, which tells it to use
  #   session[:checklist_source] (see below for possible values)
  # In the latter case (edit) it is called with species_list_id.  Now if
  #   session[:checklist_source] happens to be the same, and as far as I can
  #   tell this is always going to be the case, since edit_species_list is
  #   accessible only through show_species_list, which in turn sets
  #   session[:checklist_source] to species_list_id, then it uses
  #   session[:prev_checklist_source], which is set by show_species_list
  #   to be whatever the checklist_source was before show_species_list was
  #   called, unless it was already species_list_id, in which case it leaves
  #   it alone.  Other places session[:checklist_source] is set are:
  #     list_rss_logs           :all_observations
  #     list_observations       :all_observations
  #     observation_index       :all_observations
  #     observations_by_name    :all_observations
  #     observation_search      :observation_ids (results of search)
  #     show_user_observations  :observation_ids (that user's observations)
  #     list_images             :nothing
  #     images_by_title         :nothing
  #     image_search            :nothing
  #     name_index              :all_names
  #     show_name               :observation_ids (that name)
  #     name_search             :observation_ids (that name)
  #                             :nothing         (if multiple matches)
  #   You got all that?
  # Okay, then assuming you get this far, source's values can be:
  #   :nothing              nothing
  #   :observation_ids      session[:observation_ids]
  #   :all_observations     all names used by observations
  #   :all_names            all names
  #   species_list_id       all names in species list (consensus only)
  #   [For clarity, I converted 0 to :observation_ids, and nil to :nothing. -JPH 20071130]
  # The end result of all this is simply to store an array of these names in
  #   session[:checklist] where the values are [observation_name, name_id]
  #   And this, in turn, is only used by _form_species_lists.rhtml.  (It is
  #   used to create a list of names with check-boxes beside them that you can
  #   add to the species list.)
  def calc_checklist(id)
    source = session[:checklist_source]
    list = []
    query = nil
    user = session['user']
    if source == id
      source = session[:prev_checklist_source] || source
    end
    source_str = source.to_s
    if source.to_s == 'observation_ids'
      # Disabled as part of new prev/next.  Not reimplemented given impending checklist work.
      flash_warning "Search based checklists are no longer supported."
    elsif source.to_s == 'all_observations'
      query = "select distinct n.observation_name, n.id, n.search_name
        from names n, namings g
        where n.id = g.name_id
        order by n.search_name"
    elsif source.to_s == 'all_names'
      query = "select distinct observation_name, id, search_name
        from names
        order by search_name"
    elsif source.to_s == 'nothing'
      # This used to be nil. -JPH 20071130
    else # All that's left is species_list_id (i.e. integer)
      # Used to list everything, but that's too slow
      query = "select distinct n.observation_name, n.id, n.search_name
        from names n, observations o, observations_species_lists os
        where os.species_list_id = %s and os.observation_id = o.id
          and n.id = o.name_id
        order by n.search_name" % source.to_i
    end
    if query
      data = Observation.connection.select_all(query)
      for d in data
        list.push([d['observation_name'], d['id']])
      end
    end
    session[:checklist] = list
  end

  # Get list of names from species_list that are deprecated.
  def get_list_of_deprecated_names(spl)
    result = nil
    user = session['user']
    for obs in spl.observations
      name = obs.preferred_name(user)
      if name.deprecated
        result = [] if result.nil?
        unless result.member?(name.search_name) or
               result.member?(name.text_name)
          result.push(name.search_name)
        end
      end
    end
    return result
  end

  # This creates abd adds observations for any names not already in the list.
  # It fills in dates, location, and even notes as well as it can.  All saved.
  # Used by process_species_list.
  # Inputs:
  #   species_list      List we're adding observations to.
  #   type_str          For diagnostics: "created" or "updated".
  #   user              Owner of list.
  #   sorter            Names from the text list.
  #   params[:member][:notes]           Notes to use for new observations.
  #   params[:chosen_approved_names]    Names from radio boxes.
  #   params[:checklist_data]           Names from LHS check boxes.
  def construct_observations(species_list, params, type_str, user, sorter)
    species_list.log("Species list %s by %s" % [type_str, user.login])
    flash_notice "Species List was successfully #{type_str}."
    #
    # Put together a list of arguments to use when creating new observations.
    sp_args = {
      :created  => species_list.modified,
      :modified => species_list.modified,
      :user     => user,
      :where    => species_list.where,
      :specimen => 0,
      :notes    => params[:member][:notes]
    }
    sp_when = species_list.when # Can't use params since when is split up
    #
    # This updates certain observation namings already in the list.  It looks
    # for namings that are deprecated, then replaces them with approved
    # synonyms which the user has chosen via radio boxes in
    # params[:chosen_approved_names].
    species_list.update_names(params[:chosen_approved_names])
    #
    # Add all "single names" from text list into species_list.  Creates a new
    # observation for each name.  What are "single names", incidentally??
    for name, timestamp in sorter.single_names
      sp_args[:when] = timestamp || sp_when
      species_list.construct_observation(name, sp_args)
    end
    #
    # Add checked names from LHS check boxes.  It doesn't check if they are
    # already in there; it creates new observations for each and stuffs it in.
    sp_args[:when] = sp_when
    if params[:checklist_data]
      for key, value in params[:checklist_data]
        if value == "checked"
          name = find_chosen_name(key.to_i, params[:chosen_approved_names])
          species_list.construct_observation(name, sp_args)
        end
      end
    end
  end

  # Finds name for id, looking up synonyms already chosen in radio boxes.
  # (alternatives hash comes from params[:chosen_approved_names])
  # Helper for construct_observations.
  def find_chosen_name(id, alternatives)
    name = Name.find(id)
    if alternatives
      alt_id = alternatives[name.search_name.gsub(/\W/, "_")] # Compensate for gsub in _form_species_list.
      if alt_id
        name = Name.find(alt_id.to_i)
      end
    end
    name
  end
end
