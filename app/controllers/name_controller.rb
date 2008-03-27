# Copyright (c) 2008 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

################################################################################
#
#  Views:
#    name_index         Alphabetical list of all names, used or otherwise.
#    observation_index  Alphabetical list of names people have seen.
#    show_name          Show info about name.
#    show_past_name     Show past versions of name info.
#    edit_name          Edit name info.
#    change_synonyms
#    deprecate_name
#    approve_name
#    bulk_name_edit     Create/synonymize/deprecate a list of names.
#    map                Show distribution map.
#
#  Admin Tools:
#    cleanup_versions
#    do_maintenance
#
#  Helpers:
#    name_locs(name_id)             List of locs where name has been observed.
#    find_target_names(...)         (used by edit_name)
#    deprecate_synonym(name, user)  (used by change_synonyms)
#    check_for_new_synonym(...)     (used by change_synonyms)
#    dump_sorter(sorter)            Error diagnostics for change_synonyms.
#
################################################################################

class NameController < ApplicationController
  before_filter :login_required, :except => [
    :auto_complete_for_proposed_name,
    :map,
    :name_index,
    :name_search,
    :observation_index,
    :show_name,
    :show_past_name
  ]

  # Paginate and select name index data in prep for name_index view.
  # Input:   params['page'], params['letter'], @name_data
  # Outputs: @letter, @letters, @name_data, @name_subset, @page, @pages
  def name_index_helper
    @letter = params[:letter]
    @page = params[:page]

    # Gather hash of letters that actually have names.
    @letters = {}
    for d in @name_data
      match = d['display_name'].match(/([A-Z])/)
      if match
        l = d['first_letter'] = match[1]
        @letters[l] = true
      end
    end

    # If user's clicked on a letter, remove all names above that letter.
    if @letter
      @name_data = @name_data.select {|d| d['first_letter'][0] >= @letter[0]}
    end

    # Paginate the remaining names_.
    @pages, @name_subset = paginate_array(@name_data, 100)
  end

  # List all the names
  def name_index
    store_location
    session[:list_members] = nil
    session[:new_names] = nil
    session[:checklist_source] = :all_names
    @title = "Name Index"
    @name_data = Name.connection.select_all %(
      SELECT id, display_name
      FROM names
      ORDER BY text_name asc, author asc
    )
    name_index_helper
  end

  # Just list the names that have observations
  def observation_index
    store_location
    session[:list_members] = nil
    session[:new_names] = nil
    session[:checklist_source] = :all_observations
    @title = "Observation Index"
    @name_data = Name.connection.select_all %(
      SELECT distinct names.id, names.display_name
      FROM names, observations
      WHERE observations.name_id = names.id
      ORDER BY names.text_name asc, author asc
    )
    name_index_helper
    render :action => 'name_index'
  end

  # Searches name, author, notes, and citation.
  # Redirected from: pattern_search (search bar)
  # View: name_index
  # Inputs:
  #   session[:pattern]
  #   session['user']
  # Only one match: redirects to show_name.
  # Multiple matches: sets @name_data and renders name_index.
  def name_search
    store_location
    @user = session['user']
    @layout = calc_layout_params
    @pattern = session[:pattern]
    @title = "Names matching '#{@pattern}'"
    sql_pattern = "%#{@pattern.gsub(/[*']/,"%")}%"
    conditions = field_search(["search_name", "notes", "citation"], sql_pattern)
    session[:checklist_source] = :nothing
    @name_data = Name.connection.select_all %(
      SELECT distinct id, display_name
      FROM names
      WHERE #{conditions}
      ORDER BY text_name asc, author asc
    )
    len = @name_data.length
    if len == 1
      redirect_to :action => 'show_name', :id => @name_data[0]['id']
    else
      if len == 0
        flash_warning "No names matching '#{@pattern}' found."
      end
      name_index_helper
      render :action => 'name_index'
    end
  end

  # AJAX request used for autocompletion of "what" field in deprecate_name.
  # View: none
  # Inputs: params[:proposed][:name]
  # Outputs: none
  def auto_complete_for_proposed_name
    auto_complete_name(:proposed, :name)
  end

  # show_name.rhtml
  def show_name
    # Rough testing showed implementation without synonyms takes .23-.39 secs.
    # elapsed_time = Benchmark.realtime do
      store_location
      @name = Name.find(params[:id])
      @past_name = PastName.find(:all, :conditions => "name_id = %s and version = %s" % [@name.id, @name.version - 1]).first
      @children = @name.children

      # Matches on consensus name, any vote.
      consensus_query = %(
        SELECT o.id, o.when, o.thumb_image_id, o.where, o.location_id,
          u.name, u.login, o.user_id, n.observation_name, o.vote_cache
        FROM observations o, users u, names n
        WHERE o.name_id = %s and n.id = o.name_id and u.id = o.user_id
        ORDER BY o.vote_cache desc, o.when desc
      )

      # Matches on consensus name, only non-negative votes.
      synonym_query = %(
        SELECT o.id, o.when, o.thumb_image_id, o.where, o.location_id,
          u.name, u.login, o.user_id, n.observation_name, o.vote_cache
        FROM observations o, users u, names n
        WHERE o.name_id = %s and n.id = o.name_id and u.id = o.user_id and
          (o.vote_cache >= 0 || o.vote_cache is null)
        ORDER BY o.vote_cache desc, o.when desc
      )

      # Matches on non-consensus namings, any vote.
      other_query = %(
        SELECT o.id, o.when, o.thumb_image_id, o.where, o.location_id,
          u.name, u.login, o.user_id, n.observation_name, g.vote_cache
        FROM observations o, users u, names n, namings g
        WHERE g.name_id = %s and o.id = g.observation_id and
          n.id = o.name_id and u.id = o.user_id and
          o.name_id != g.name_id
        ORDER BY g.vote_cache desc, o.when desc
      )

      # Get list of observations matching on consensus: these are "reliable".
      @consensus_data = Observation.connection.select_all(consensus_query % params[:id])

      # Get list of observations matching on other names: "look-alikes".
      @other_data = Observation.connection.select_all(other_query % params[:id])

      # Get list of observations matching any of its synonyms.
      @synonym_data = []
      synonym = @name.synonym
      if synonym
        for n in synonym.names
          if n != @name
            data = Observation.connection.select_all(synonym_query % n.id)
            @synonym_data += data
          end
        end
      end

      # Remove duplicates. (Select block sets seen[id] to true and returns true
      # for the first occurrance of an id, else implicitly returns false.)
      seen = {}
      @consensus_data = @consensus_data.select {|d|
        seen[d["id"]] = true if !seen[d["id"]] }
      @synonym_data = @synonym_data.select {|d|
        seen[d["id"]] = true if !seen[d["id"]] }
      @other_data = @other_data.select {|d|
        seen[d["id"]] = true if !seen[d["id"]] }

      # Gather full list of IDs for the prev/next buttons to cycle through.
      observation_ids = []
      @user = session['user']
      for d in @consensus_data + @synonym_data + @other_data
        observation_ids.push(d["id"].to_i)
      end

      # Paginate the two sections independently.
      per_page = 12
      @consensus_page = params['consensus_page']
      @consensus_page = 1 if !@consensus_page
      @synonym_page = params['synonym_page']
      @synonym_page = 1 if !@synonym_page
      @other_page = params['other_page']
      @other_page = 1 if !@other_page
      @consensus_pages, @consensus_data =
        paginate_array(@consensus_data, per_page, @consensus_page)
      @synonym_pages, @synonym_data =
        paginate_array(@synonym_data, per_page, @synonym_page)
      @other_pages, @other_data =
        paginate_array(@other_data, per_page, @other_page)
      @consensus_data = [] if !@consensus_data
      @synonym_data = [] if !@synonym_data
      @other_data = [] if !@other_data

      # By default we query the consensus name above, but if the user
      # is logged in we need to redo it and calc the preferred name for each.
      # Note that there's no reason to do duplicate observations.  (Note, only
      # need to do this to subset on the page we can actually see.)
      if @user = session['user']
        for d in @consensus_data + @synonym_data + @other_data
          d["observation_name"] = Observation.find(d["id"].to_i).preferred_name(@user).observation_name
        end
      end

      session[:checklist_source] = :observation_ids
      session[:observation_ids] = observation_ids
      session[:image_ids] = nil
    # end
    # logger.warn("show_name took %s\n" % elapsed_time)
  end

  def show_past_name
    store_location
    @past_name = PastName.find(params[:id])
    @other_versions = PastName.find(:all, :conditions => "name_id = %s" % @past_name.name_id, :order => "version desc")
  end

  # show_name.rhtml -> edit_name.rhtml
  # Updates modified and saves changes
  def edit_name
    @user = session['user']
    if verify_user()
      @name = Name.find(params[:id])
      @can_make_changes = true
      if @user.id != 0
        for obs in @name.observations
          if obs.user.id != @user.id
            @can_make_changes = false
            break
          end
        end
      end
      if request.method == :post
        text_name = (params[:name][:text_name] || '').strip
        author = (params[:name][:author] || '').strip
        begin
          notes = params[:name][:notes]
          (@name, old_name) = find_target_names(params[:id], text_name, author, notes)
          if text_name == ''
            text_name = @name.text_name
          end
          # Don't allow author to be cleared by using any author you can find...
          if author == ''
            author = @name.author || ''
            if author == '' && old_name
              author = old_name.author || ''
            end
          end
          old_search_name = @name.search_name
          count = 0
          current_time = Time.now
          @name.modified = current_time
          count += 1
          alt_ids = @name.change_text_name(text_name, author, params[:name][:rank])
          @name.citation = params[:name][:citation]
          if notes == '' && old_name # no new notes given and merge happened
            notes = @name.notes # @name's notes
            if notes.nil? or (notes == '')
              notes = old_name.notes # try old_name's notes
            end
          end
          @name.notes = notes
          unless PastName.check_for_past_name(@name, @user, "Name updated by #{@user.login}")
            unless @name.id
              raise "Update_name called on a name that doesn't exist."
            end
          end
          if old_name # merge happened
            for o in old_name.observations
              o.name = @name
              o.modified = current_time
              o.save
            end
            for g in old_name.namings
              g.name = @name
              g.modified = current_time
              g.save
            end
            if @user.id != 0
              old_name.log("#{old_search_name} merged with #{@name.search_name}")
            end
            old_name.destroy
          end
        rescue RuntimeError => err
          flash_error err.to_s
          flash_object_errors(@name)
        else
          redirect_to :action => 'show_name', :id => @name
        end
      end
    end
  end

  # change_synonyms.rhtml -> transfer_synonyms -> show_name.rhtml
  def change_synonyms
    if verify_user()
      @user = session['user']
      @name = Name.find(params[:id])
      @list_members     = nil
      @new_names        = nil
      @synonym_name_ids = []
      @synonym_names    = []
      @deprecate_all    = "checked"
      if request.method == :post
        list = params[:synonym][:members].squeeze(" ") # Get rid of extra whitespace while we're at it
        deprecate = (params[:deprecate][:all] == "checked")
        construct_approved_names(list, params[:approved_names], @user, deprecate)
        sorter = NameSorter.new
        sorter.sort_names(list)
        sorter.append_approved_synonyms(params[:approved_synonyms])
        # When does this fail??
        if !sorter.only_single_names
          dump_sorter(sorter)
        elsif !sorter.only_approved_synonyms
          flash_notice("Please confirm that this is what you intended.")
        else
          timestamp = Time.now
          synonym = @name.synonym
          if synonym.nil?
            synonym = Synonym.new
            synonym.created = timestamp
            @name.synonym = synonym
            @name.modified = timestamp # Change timestamp, but not modifier
            @name.save # Not creating a PastName since they don't track synonyms
          end
          proposed_synonyms = params[:proposed_synonyms] || {}
          for n in sorter.all_names
            if proposed_synonyms[n.id.to_s] != '0'
              synonym.transfer(n)
            end
          end
          for name_id in sorter.proposed_synonym_ids
            n = Name.find(name_id)
            if proposed_synonyms[name_id.to_s] != '0'
              synonym.transfer(n)
            end
          end
          check_for_new_synonym(@name, synonym.names, params[:existing_synonyms] || {})
          synonym.modified = timestamp
          synonym.save
          success = true
          if deprecate
            for n in sorter.all_names
              success = false if !deprecate_synonym(n, @user)
            end
          end
          if success
            redirect_to :action => 'show_name', :id => @name
          else
            flash_object_errors(@name)
            flash_object_errors(@name.synonym)
          end
        end
        @list_members     = sorter.all_line_strs.join("\r\n")
        @new_names        = sorter.new_name_strs.uniq
        @synonym_name_ids = sorter.proposed_synonym_ids.uniq
        @synonym_names    = @synonym_name_ids.map {|id| Name.find(id)}
        @deprecate_all    = params[:deprecate][:all]
      end
    end
  end

  def deprecate_name
    if verify_user()
      @user    = session['user']
      @name    = Name.find(params[:id])
      @what    = (params[:proposed] && params[:proposed][:name] ? params[:proposed][:name] : '').strip
      @comment = (params[:comment] && params[:comment][:comment] ? params[:comment][:comment] : '').strip
      @list_members     = nil
      @new_names        = []
      @synonym_name_ids = []
      @synonym_names    = []
      @deprecate_all    = "checked"
      @names            = []
      if request.method == :post
        if @what == ''
          flash_error "Must choose a preferred name."
        else
          if params[:chosen_name] && params[:chosen_name][:name_id]
            new_names = [Name.find(params[:chosen_name][:name_id])]
          else
            new_names = Name.find_names(@what)
          end
          if new_names.length == 0
            new_names = [create_needed_names(params[:approved_name], @what, @user)]
          end
          target_name = new_names.first
          if target_name
            @names = new_names
            if new_names.length == 1
              @name.merge_synonyms(target_name)
              target_name.change_deprecated(false)
              current_time = Time.now
              PastName.check_for_past_name(target_name, @user, "Preferred over #{@name.search_name} by #{@user.login}.")
              @name.change_deprecated(true)
              PastName.check_for_past_name(@name, @user, "Deprecated in favor of #{target_name.search_name} by #{@user.login}.")
              comment_join = @comment == "" ? "." : ":\n"
              @name.prepend_notes("Deprecated in favor of" +
                " #{target_name.search_name} by #{@user.login} on " +
                Time.now.to_formatted_s(:db) + comment_join + @comment)
              redirect_to :action => 'show_name', :id => @name
            end
          end
        end
      end
    end
  end

  def approve_name
    if verify_user()
      @user = session['user']
      @name = Name.find(params[:id])
      @approved_names = @name.approved_synonyms
      if request.method == :post
        if params[:deprecate][:others] == '1'
          for n in @name.approved_synonyms
            n.change_deprecated(true)
            PastName.check_for_past_name(n, @user, "Deprecated in favor of #{@name.search_name} by #{@user.login}")
          end
        end
        # @name.version = @name.version + 1
        @name.change_deprecated(false)
        PastName.check_for_past_name(@name, @user, "Approved by #{@user.login}")
        comment = (params[:comment] && params[:comment][:comment] ?
           params[:comment][:comment] : "").strip
        comment_join = comment == "" ? "." : ":\n"
        @name.prepend_notes("Approved by #{@user.login} on " +
          Time.now.to_formatted_s(:db) + comment_join + comment)
        redirect_to :action => 'show_name', :id => @name
      end
    end
  end

  # name_index/create_species_list -> bulk_name_edit
  def bulk_name_edit
    if verify_user()
      @user = session['user']
      @list_members = nil
      @new_names    = nil
      if request.method == :post
        list = params[:list][:members].squeeze(" ") # Get rid of extra whitespace while we're at it
        construct_approved_names(list, params[:approved_names], @user)
        sorter = setup_sorter(params, nil, list)
        if sorter.only_single_names
          sorter.create_new_synonyms()
          flash_notice "All names are now in the database."
          redirect_to :controller => 'observer', :action => 'list_rss_logs'
        else
          if sorter.new_name_strs != []
            # This error message is no longer necessary.
            # flash_error "Unrecognized names including #{sorter.new_name_strs[0]} given."
          else
            # Same with this one.
            # flash_error "Ambiguous names including #{sorter.multiple_line_strs[0]} given."
          end
          @list_members = sorter.all_line_strs.join("\r\n")
          @new_names    = sorter.new_name_strs.uniq.sort
        end
      end
    end
  end

  def map
    name_id = params[:id]
    @name = Name.find(name_id)
    locs = name_locs(name_id)
    print "NameController.map:locs.length: #{locs.length}\n"
    @synonym_data = []
    synonym = @name.synonym
    if synonym
      print "NameController.map:locs.length: have synonym\n"
      for n in synonym.names
        if n != @name
          syn_locs = name_locs(n.id)
          print "NameController.map:syn_locs.length: #{syn_locs.length}\n"
          for l in syn_locs
            unless locs.member?(l)
              locs.push(l)
            end
          end
        end
      end
    end
    print "NameController.map:locs.length 2: #{locs.length}\n"
    @map = nil
    @header = nil
    if locs.length > 0
      @map = make_map(locs)
      @header = "#{GMap.header}\n#{finish_map(@map)}"
    end
  end

  def cleanup_versions
    if check_permission(1)
      id = params[:id]
      name = Name.find(id)
      past_names = PastName.find(:all, :conditions => ["name_id = ?", id], :order => "version desc")
      v = past_names.length
      name.version = v
      name.user_id = 1
      name.save
      v -= 1
      for pn in past_names
        pn.version = v
        pn.save
        v -= 1
      end
    end
    redirect_to :action => 'show_name', :id => id
  end

  def do_maintenance
    if check_permission(0)
      @data = []
      @users = {}
      for n in Name.find(:all)
        eldest_obs = nil
        for o in n.observations
          if eldest_obs.nil? or (o.created < eldest_obs.created)
            eldest_obs = o
          end
        end
        if eldest_obs
          user = eldest_obs.user
          if n.user != user
            found_user = false
            for p in n.past_names
              if p.user == user
                found_user = true
              end
            end
            unless found_user
              if @users[user.login]
                @users[user.login] += 1
              else
                @users[user.login] = 1
              end
              @data.push({:name => n.display_name, :id => n.id, :login => user.login})
              pn = PastName.make_past_name(n)
              pn.user = user
              pn.save
              n.version += 1
              n.save
            end
          end
        end
      end
    else
      flash_error "Maintenance operations can only be done by the admin user."
      redirect_to :controller => "observer", :action => "list_rss_logs"
    end
  end

################################################################################

  # Finds the intended name and if another name matching name exists,
  # then ensure it is mergable.  Returns [target_name, other_name]
  def find_target_names(id_str, text_name, author, notes)
    id = id_str.to_i
    page_name = Name.find(id)
    other_name = nil
    matches = []
    if author != ''
      matches = Name.find(:all, :conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
    else
      matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
    end
    for m in matches
      if m.id != id
        other_name = m # Just take the first one
        break
      end
    end
    result = [page_name, other_name] # Default
    if other_name # Is there a reason to prefer other_name?
      if other_name.has_notes?
        # If other_name's notes are going to get overwritten throw an error
        if notes && (notes != '') && (other_name.notes != notes)
          raise "The name, %s, is already in use and %s has notes" % [text_name, other_name.search_name]
        end
        result = [other_name, page_name]
      elsif !page_name.has_notes?
        # Neither has notes, so we need another criterion
        if page_name.deprecated and !other_name.deprecated # Prefer valid names
          result = [other_name, page_name]
        elsif (other_name.deprecated == page_name.deprecated) and (other_name.version >= page_name.version)
          result = [other_name, page_name]
        end
      end
    end
    result
  end

  def deprecate_synonym(name, user)
    unless name.deprecated
      begin
        count = 0
        name.change_deprecated(true)
        PastName.check_for_past_name(name, user, "Name deprecated by #{user.login}.")
      rescue RuntimeError => err
        flash_error err.to_s
        return false
      end
    end
    return true
  end

  def dump_sorter(sorter)
    logger.warn("tranfer_synonyms: only_single_names or only_approved_synonyms is false")
    logger.warn("New names:")
    for n in sorter.new_line_strs
      logger.warn(n)
    end
    logger.warn("\nSingle names:")
    for n in sorter.single_line_strs
      logger.warn(n)
    end
    logger.warn("\nMultiple names:")
    for n in sorter.multiple_line_strs
      logger.warn(n)
    end
    if sorter.chosen_names
      logger.warn("\nChosen names:")
      for n in sorter.chosen_names
        logger.warn(n)
      end
    end
    logger.warn("\nSynonym name ids:")
    for n in sorter.proposed_synonym_ids.uniq
      logger.warn(n)
    end
  end

  # Look through the candidates for names that are not marked in checks.
  # If there are more than 1, then create a new synonym containing those taxa.
  # If there is only one then remove it from any synonym it belongs to
  def check_for_new_synonym(name, candidates, checks)
    new_synonym_members = []
    for n in candidates
      if (name != n) && (checks[n.id.to_s] == "0")
        new_synonym_members.push(n)
      end
    end
    len = new_synonym_members.length
    if len > 1
      new_synonym = Synonym.new
      new_synonym.created = Time.now
      new_synonym.save
      for n in new_synonym_members
        new_synonym.transfer(n)
      end
    elsif len == 1
      new_synonym_members[0].clear_synonym
    end
  end

  def name_locs(name_id)
    Location.find(:all, {
      :include => :observations,
      :conditions => ["observations.name_id = ? and
        observations.is_collection_location = true and
        (observations.vote_cache >= 0 or observations.vote_cache is NULL)", name_id]
    })
  end
end
