#
#  Views: ("*" - login required, "R" - root required)
#     name_index          Alphabetical list of all names, used or otherwise.
#     observation_index   Alphabetical list of names people have seen.
#     name_search
#     show_name           Show info about name.
#     show_past_name      Show past versions of name info.
#   * create_name         Create new name.
#   * edit_name           Edit name info.
#   * change_synonyms     Change list of synonyms for a name.
#   * deprecate_name      Deprecate name in favor of another.
#   * approve_name        Flag given name as "accepted" (others could be, too).
#   * bulk_name_edit      Create/synonymize/deprecate a list of names.
#     map                 Show distribution map.
#   * review_authors      Let authors/reviewers add/remove authors.
#   * author_request      Let non-authors request authorship credit.
#   * send_author_request (post method of author_request)
#
#  AJAX:
#     auto_complete_name
#
#  Admin Tools:
#   R cleanup_versions
#   R do_maintenance
#
#  Helpers:
#    name_locs(name_id)             List of locs where name has been observed.
#    find_target_names(...)         (used by edit_name)
#    deprecate_synonym(name, user)  (used by change_synonyms)
#    check_for_new_synonym(...)     (used by change_synonyms)
#    dump_sorter(sorter)            Error diagnostics for change_synonyms.
#    name_index_helper
#
################################################################################

class NameController < ApplicationController
  before_filter :login_required, :except => [
    :advanced_obj_search,
    :authored_names,
    :auto_complete_name,
    :eol,
    :eol_preview,
    :map,
    :name_index,
    :name_search,
    :names_by_author,
    :names_by_editor,
    :observation_index,
    :show_name,
    :show_past_name
  ]

  # Process AJAX request for autocompletion of mushroom name.  It reads the
  # first letter of the field, and returns all the names beginning with it.
  # Inputs: params[:letter]
  # Outputs: renders sorted list of names, one per line, in plain text
  def auto_complete_name
    letter = params[:letter] || ''
    if letter.length > 0
      @items = Name.connection.select_values %(
        SELECT text_name FROM names
        WHERE LOWER(text_name) LIKE '#{letter}%'
        AND misspelling = false
        ORDER BY text_name ASC
      )
    else
      letter = ' '
      @items = []
    end
    render(:inline => letter + '<%= @items.uniq.map {|n| h(n) + "\n"}.join("") %>')
  end

  # Paginate and select name index data in prep for name_index view.
  # Input:   params['page'], params['letter'], @name_data
  # Outputs: @letter, @letters, @name_data, @name_subset, @page, @pages
  def name_index_helper
    @letter = params[:letter]
    @page = params[:page]
    @letters, @name_subset = paginate_letters(@name_data, 100) \
      {|d| d['display_name'].match(/([a-z])/i) ? $~[1] : nil}
    @pages, @name_subset = paginate_array(@name_subset, @letter.to_s.empty? ? 100: 1e6)
  end

  # List all the names
  def name_index
    store_location
    session[:list_members] = nil
    session[:new_names] = nil
    session[:checklist_source] = :all_names
    @title = :name_index_name_index.t
    @name_data = Name.connection.select_all %(
      SELECT id, display_name
      FROM names
      WHERE misspelling = false
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
    @title = :name_index_observation_index.t
    @name_data = Name.connection.select_all %(
      SELECT distinct names.id, names.display_name
      FROM names, observations
      WHERE observations.name_id = names.id
      ORDER BY names.text_name asc, author asc
    )
    name_index_helper
    render(:action => 'name_index')
  end

  # Just list the names that have observations
  def needed_descriptions
    store_location
    session[:list_members] = nil
    session[:new_names] = nil
    session[:checklist_source] = :all_observations
    @name_data = Name.connection.select_all %(
      SELECT name_counts.count, names.id, names.display_name
      FROM names left outer join draft_names on names.id = draft_names.name_id,
         (SELECT count(*) AS count, name_id
                   FROM observations group by name_id)
                  AS name_counts
      WHERE names.id = name_counts.name_id
      AND names.rank = 'Species'
      AND (names.gen_desc is NULL or names.gen_desc = '')
      AND name_counts.count > 1
      AND draft_names.name_id is NULL
      AND current_timestamp - modified > #{1.week.to_i}
      ORDER BY name_counts.count desc, names.text_name asc
      LIMIT 100
    )
  end

  # Searches name, author, notes, and citation.
  # Redirected from: pattern_search (search bar)
  # View: name_index
  # Inputs:
  #   session[:pattern]
  # Only one match: redirects to show_name.
  # Multiple matches: sets @name_data and renders name_index.
  def name_search
    store_location
    pattern = params[:pattern] || session[:pattern] || ''
    title = :name_index_matching.t(:pattern => pattern)
    id = pattern.to_i
    name_data = nil
    if pattern == id.to_s
      begin
        name = Name.find(id)
        if name
          name_data = [{'id' => id, 'display_name' => name.display_name}]
        end
      rescue ActiveRecord::RecordNotFound
      end
    end
    if name_data.nil?
      sql_pattern = "%#{pattern.gsub(/[*']/,"%")}%"
      conditions = field_search(["search_name", "citation"] + Name.all_note_fields, sql_pattern)
      session[:checklist_source] = :nothing
      name_data = Name.connection.select_all %(
        SELECT distinct id, display_name
        FROM names
        WHERE #{conditions} AND misspelling = false
        ORDER BY text_name asc, author asc
      )
    end
    @pattern = pattern
    show_name_data(title, name_data, :name_search_none_found.t(:pattern => pattern))
  end
  
  def authored_names
    base_data = Name.connection.select_all %(
      SELECT distinct names.id, names.display_name, users.login, names.review_status
      FROM names, authors_names, users
      WHERE names.id = authors_names.name_id
      AND authors_names.user_id = users.id
      ORDER BY names.text_name asc, names.author asc
    )
    last_name_id = users = name = nil
    name_data = []
    for row in base_data:
      if last_name_id != row['id']
        last_row = row.clone
        name_data.push(last_row)
        last_name_id = row['id']
        users = [row['login']]
        name = Name.find(last_name_id)
        field_count, size_count = name.note_status()
      else
        users.push(row['login'])
      end
      last_row['extra'] = "#{users.join(', ')}</td><td>#{field_count}/#{size_count}</td><td>#{last_row['review_status'].to_sym.t}"
      # last_row['display_name'] = "#{row['display_name']} (#{users.join(', ')} )"
    end
    show_name_data(:authored_names_title.t, name_data, :authored_names_error.t)
  end
    
  def names_by_author
    names_by(:author, :names_by_author_title, :names_by_author_error)
  end
  
  def names_by_editor
    names_by(:editor, :names_by_editor_title, :names_by_editor_error)
  end
  
  def names_by(role, title, error)
    user = User.find(params[:id])
    if user
      name_data = Name.connection.select_all %(
        SELECT distinct names.id, names.display_name
        FROM names, #{role}s_names
        WHERE names.id = #{role}s_names.name_id
        AND #{role}s_names.user_id = #{user.id}
        ORDER BY names.text_name asc, names.author asc
      )
      for row in name_data:
        row['display_name'] = "#{row['display_name']} [#{user.login}]"
      end
      user_name = user.legal_name
      show_name_data(title.t(:name => user_name), name_data, error.t(:name => user_name))
    else
      redirect_to(:name_index)
    end
  end
  
  def show_name_data(title, name_data, error)
    store_location
    @layout = calc_layout_params
    @title = title
    @name_data = name_data
    len = name_data.length
    if len == 1
      redirect_to(:action => 'show_name', :id => name_data[0]['id'])
    else
      if len == 0
        flash_warning(error)
      end
      name_index_helper
      render(:action => 'name_index')
    end
  end
  
  def advanced_obj_search
    begin
      @layout = calc_layout_params
      query = calc_advanced_search_query("SELECT DISTINCT names.id, names.display_name FROM",
        Set.new(['names', 'observations']), params)
      query += " ORDER BY names.text_name asc, names.author asc"
      show_name_data(:advanced_search_title.l, Name.connection.select_all(query), :advanced_search_none_found.t)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search')
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
      name_id = params[:id]
      @name = Name.find(name_id)
      @past_name = @name.versions.latest
      @past_name = @past_name.previous if @past_name
      @children_data = @name.children
      @parents = @name.parents
      @interest = nil
      @interest = Interest.find_by_user_id_and_object_type_and_object_id(@user.id, 'Name', @name.id) if @user
      update_view_stats(@name)

      # In theory much of the following should really be handled by the new search_sequences,
      # but for now if it ain't broke...
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
      @consensus_data = Observation.connection.select_all(consensus_query % name_id)

      # Get list of observations matching on other names: "look-alikes".
      @other_data = Observation.connection.select_all(other_query % name_id)

      # Get list of observations matching any of its synonyms.
      @synonym_data = []
      synonym_ids = []
      synonym = @name.synonym
      if synonym
        for n in synonym.names
          if n != @name
            synonym_ids.push(n.id)
            data = Observation.connection.select_all(synonym_query % n.id)
            @synonym_data += data
          end
        end
      end

      @search_seqs = {}
      if @consensus_data.length > 0
        @search_seqs["consensus"] = calc_search(:name_observations,
          "o.name_id = %s" % name_id, "o.vote_cache desc, o.when desc").id
      end
      if @synonym_data.length > 0
        @search_seqs["synonym"] = calc_search(:synonym_observations,
          "o.name_id in (%s)" % synonym_ids.join(", "), "o.vote_cache desc, o.when desc").id
      end
      if @other_data.length > 0
        @search_seqs["other"] = calc_search(:other_observations,
          "g.name_id = %s" % name_id, "g.vote_cache desc, o.when desc").id
      end
      #consensus_search = SearchState.lookup(params, :name_observations, logger)
      #if not consensus_search.setup?
      #  consensus_search.setup(nil, , :nothing)
      #end
      #consensus_search.save if !is_robot?
      #@search_seqs = { "consensus" => consensus_search.id }

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
      session_setup

      # Paginate the sections independently.
      per_page = 12
      @children_page = params['children_page']
      @children_page = 1 if !@children_page
      @consensus_page = params['consensus_page']
      @consensus_page = 1 if !@consensus_page
      @synonym_page = params['synonym_page']
      @synonym_page = 1 if !@synonym_page
      @other_page = params['other_page']
      @other_page = 1 if !@other_page
      @children_pages, @children_data =
        paginate_array(@children_data, per_page*2, @children_page)
      @consensus_pages, @consensus_data =
        paginate_array(@consensus_data, per_page, @consensus_page)
      @synonym_pages, @synonym_data =
        paginate_array(@synonym_data, per_page, @synonym_page)
      @other_pages, @other_data =
        paginate_array(@other_data, per_page, @other_page)
      @children_data = [] if !@children_data
      @consensus_data = [] if !@consensus_data
      @synonym_data = [] if !@synonym_data
      @other_data = [] if !@other_data
      @is_reviewer = is_reviewer

      # By default we query the consensus name above, but if the user
      # is logged in we need to redo it and calc the preferred name for each.
      # Note that there's no reason to do duplicate observations.  (Note, only
      # need to do this to subset on the page we can actually see.)
      projects = []
      if @user
        for d in @consensus_data + @synonym_data + @other_data
          d["observation_name"] = Observation.find(d["id"].to_i).format_name
        end
        if @name.draft_names.length == 0
          for group in @user.user_groups
            project = group.project
            if project
              projects.push(project)
            end
          end
          projects.sort! {|x,y| x.title <=> y.title }
        end
      end
      @user_projects = projects unless projects == []

      @existing_drafts = DraftName.find_all_by_name_id(name_id, :include => :project, :order => "projects.title") # for view/edit draft section
      @existing_drafts = nil if @existing_drafts == []
      # session[:checklist_source] = :observation_ids
    # end
    # logger.warn("show_name took %s\n" % elapsed_time)
  end

  # Callback to let reviewers change the review status of a Name from the show_name page.
  def set_review_status
    id = params[:id]
    if is_reviewer
      Name.find(id).update_review_status(params[:value], @user)
    end
    redirect_to(:action => 'show_name', :id => id)
  end

  # Callback to let reviewers change the export status of a Name from the show_name page.
  def set_export_status
    id = params[:id]
    if is_reviewer
      name = Name.find(id)
      name.ok_for_export = params[:value]
      name.save
    end
    redirect_to(:action => 'show_name', :id => id)
  end

  def show_past_name
    store_location
    @name = Name.find(params[:id].to_i)
    @past_name = Name.find(params[:id].to_i) # clone or dclone?
    @past_name.revert_to(params[:version].to_i)
    @other_versions = @name.versions.reverse
  end

  # name_index.rhtml -> create_name.rhtml
  def create_name
    if verify_user()
      if request.method == :post
        begin
          text_name = (params[:name][:text_name] || '').strip
          author = (params[:name][:author] || '').strip
          name_str = text_name
          params[:name][:classification] = Name.validate_classification(params[:name][:rank], params[:name][:classification])
          matches = nil
          if author != ''
            matches = Name.find(:all, :conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
            name_str += " #{author}"
          else
            matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
          end
          if matches.length > 0
            flash_error(:name_create_already_exists.t(:name => name_str))
            name = matches[0]
          else
            names = Name.names_from_string(name_str)
            name = names.last
            if name.nil?
              raise :runtime_unable_to_create_name.t(:name => name_str)
            end
            name.citation = params[:name][:citation]
            name.rank = params[:name][:rank] # Not quite right since names_from_string sets rank too
            name.change_text_name(text_name, author, params[:name][:rank]) # Validates parse

            has_notes = false
            for f in Name.all_note_fields
              note = params[:name][f]
              has_notes |= (note and (note != ''))
              name.send("#{f}=", note)
            end
            if has_notes
              name.license_id = params[:name][:license_id]
            else
              name.license_id = nil
            end
            for n in names
              if n
                n.user_id = @user.id
                n.save
                n.add_editor(@user)
              end
            end
          end
        rescue RuntimeError => err
          # Anything causing changes not to get saved ends up here.
          @name = Name.new
          flash_error(err.to_s) if !err.nil?
          flash_object_errors(@name)
          @name.attributes = params[:name]
          @licenses = License.current_names_and_ids()
          @can_make_changes = true

        else
          # If no errors occurred, changes must've been made successfully.
          redirect_to(:action => 'show_name', :id => name)
        end
      else
        @name = Name.new
        @licenses = License.current_names_and_ids()
        @name.rank = :Species
        @can_make_changes = true
      end
    end
  end

  def blank_notes(note_hash)
    result = true
    for key, value in note_hash
      unless (value.nil? or value == '')
        result = false
        break
      end
    end
    result
  end
  
  # show_name.rhtml -> edit_name.rhtml
  # Updates modified and saves changes
  def edit_name
    any_errors = false
    if verify_user()
      @name = Name.find(params[:id])
      @licenses = License.current_names_and_ids(@name.license)
      @misspelling = false
      if @name.is_misspelling? || (params[:name] && params[:name][:misspelling] == '1')
        @name_primer = Name.primer(@user)
      end

      # Only allowed to make substantive changes it you own all the references to it.
      # I think checking that the user owns all the namings that use it is correct.
      # Maybe we should also check observations?  But the observation simply caches
      # the winning naming's name.  Actually not necessarily: obs might use the accepted
      # name if the winning name is deprecated.  Hmmm, I'll check it to be safe.
      @can_make_changes = true
      if @user.id != 0
        for obj in @name.namings + @name.observations
          if obj.user.id != @user.id
            @can_make_changes = false
            break
          end
        end
      end

      if request.method == :post
        begin
          current_time = Time.now
          text_name = (params[:name][:text_name] || '').strip
          author = (params[:name][:author] || '').strip

          # Grab all the notes sections: general description, look-alikes, etc.
          all_notes = {}
          params[:name][:classification] = Name.validate_classification(params[:name][:rank], params[:name][:classification])
          for f in Name.all_note_fields
            all_notes[f] = params[:name][f]
          end

          # It is possible to change a Name's name if no one is using it yet
          # (or the user owns all uses of it).  This tells us which Name we're
          # actually going to change (@name), and if we need to merge and
          # remove a "duplicate" (old_name). 
          (@name, old_name) = find_target_names(params[:id], text_name, author, all_notes)
          if text_name == ''
            text_name = @name.text_name
          end

          # Don't allow author to be cleared if we can find an author in either
          # of the pre-existing matching names.
          if author == ''
            author = @name.author || ''
            if author == '' && old_name
              author = old_name.author || ''
            end
          end

          # Save changes to name.  (Keep old name for log message if we are
          # merging old_name into @name.)  Note: alt_ids is not used.
          old_display_name = @name.display_name
          alt_ids = @name.change_text_name(text_name, author, params[:name][:rank])

          # Save changes to citation.
          @name.citation = params[:name][:citation]

          # Prevent user from erasing all the notes.  This also has the effect of
          # merging notes from the old "duplicate" Name if it has any notes.  (As
          # I understand find_target_names, this should never occur.)
          if blank_notes(all_notes) && old_name # no new notes given and merge happened
            all_notes = @name.all_notes
            if blank_notes(all_notes)
              all_notes = old_name.all_notes # try old_name's notes
            end
          end

          # Save changes to notes.
          @name.set_notes(all_notes)

          # Save change to license_id.
          # (Clear out license_id if there are no notes.)
          if @name.has_any_notes?
            @name.license_id = params[:name][:license_id]
          else
            @name.license_id = nil
          end

          # Let user call this a misspelling.  Look up the correct name
          # via synonyms.  There can be multiple accepted names, in which
          # case look for the one that shares the most letters(!)  If none
          # are close, notify user and ask them to be explicit.
          @misspelling = (params[:name][:misspelling].to_s == '1')
          @correct_spelling = params[:name][:correct_spelling]
          if !@misspelling
            @name.misspelling = false
            @name.correct_spelling = nil
          else
            name2 = nil

            # Look up correct spelling if given explicitly.
            if @correct_spelling.to_s != ''
              @name.misspelling = true
              name2 = Name.find_by_search_name(@correct_spelling) 
              name2 ||= Name.find_by_text_name(@correct_spelling) 
              if !name2
                flash_error(:form_names_misspelling_bad.t)
              elsif name2.id == @name.id
                flash_error(:form_names_misspelling_same.t)
                name2 = nil
              end

            # Try to guess if not given explicitly.
            elsif !@name.correct_spelling
              @name.misspelling = true
              synonyms = @name.synonym ? @name.synonym.names - [@name] : []
              if synonyms.length == 0
                flash_error(:form_names_misspelling_no_synonyms.t)
              else
                candidates = []
                approved_candidates = []
                for synonym in synonyms
                  # Count letters in one but not the other and vice versa.
                  val  = 0
                  copy = synonym.text_name
                  @name.text_name.each_char do |c|
                    if i = copy.index(c)
                      copy[i] = ''
                    else
                      val += 1
                    end
                  end
                  val += copy.length
                  candidates.push(synonym)          if val < 5
                  approved_candidates.push(synonym) if val < 5 && !synonym.deprecated
                end
                if candidates.length == 0
                  flash_error(:form_names_misspelling_no_matches.t)
                elsif approved_candidates.length == 1
                  name2 = approved_candidates.first
                elsif candidates.length == 1
                  name2 = candidates.first
                else
                  flash_error(:form_names_misspelling_many_matches.t)
                end
              end
            end

            # Make sure correct spelling is a synonym, and not itself misspelled.
            if name2
              @name.misspelling = true
              @name.correct_spelling = name2
              @name.merge_synonyms(name2)
              @name.change_deprecated(true)
              name2.misspelling = false
              name2.correct_spelling = nil
              if name2.save_if_changed(@user,
                :log_name_unmisspelled, { :user => @user.login,
                :other => @name.display_name }, Time.now, true)
                name2.add_editor(@user)
              end
            else
              @name.misspelling = false
              @name.correct_spelling = nil
              any_errors = true
            end
          end

          # Errr... when would this ever happen?
          raise user_update_nonexisting_name.t if !@name.id

          # If substantive changes are made by a reviewer, call this act a
          # "review", even though they haven't actually changed the review
          # status.  If substantive changes are made by a non-reviewer,
          # this will revert status to unreviewed.
          if @name.save_version?
            @name.update_review_status(@name.review_status, @user, current_time)
          end

          # This saves changes, and returns true if a new version was created.
          if @name.save_if_changed(@user, :log_name_updated, { :user => @user.login }, current_time, true)
            @name.add_editor(@user)
          elsif @name.errors.length > 0
            raise :runtime_unable_to_save_changes.t
          end

          # Merge and remove "duplicate" Name.
          if old_name
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
              old_name.log(:log_name_merged, { :this => old_display_name,
                :that => @name.display_name }, true)
            end
            old_name.destroy
          end

        rescue RuntimeError => err
          # Anything causing changes not to get saved ends up here.
          flash_error(err.to_s) if !err.nil?
          flash_object_errors(@name)
          @name.attributes = params[:name]

        else
          # If no errors occurred, changes must've been made successfully.
          redirect_to(:action => 'show_name', :id => @name.id) if !any_errors
        end
      end
    end
  end

  # change_synonyms.rhtml -> transfer_synonyms -> show_name.rhtml
  def change_synonyms
    if verify_user()
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
          flash_notice :name_change_synonyms_confirm.t
        else
          timestamp = Time.now
          synonym = @name.synonym
          if synonym.nil?
            synonym = Synonym.new
            synonym.created = timestamp
            synonym.save
            @name.synonym = synonym
            if @name.save_if_changed(@user, nil, nil, timestamp, true)
              @name.add_editor(@user)
            end
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
            redirect_to(:action => 'show_name', :id => @name.id)
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
      @name    = Name.find(params[:id])
      @what    = (params[:proposed] && params[:proposed][:name] ? params[:proposed][:name] : '').strip
      @comment = (params[:comment] && params[:comment][:comment] ? params[:comment][:comment] : '').strip
      @list_members     = nil
      @new_names        = []
      @synonym_name_ids = []
      @synonym_names    = []
      @deprecate_all    = "checked"
      @names            = []
      @misspelling      = params[:is] && params[:is][:misspelling] == '1'
      if request.method == :post
        if @what == ''
          flash_error :name_deprecate_must_choose.t
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
              if target_name.save_if_changed(@user,
                :log_name_approved, { :user => @user.login,
                :other => @name.display_name }, current_time, true)
                target_name.add_editor(@user)
              end
              @name.change_deprecated(true)
              if @misspelling
                @name.misspelling = true
                @name.correct_spelling = target_name
              end
              comment_join = @comment == "" ? "." : ":\n"
              @name.prepend_notes("Deprecated in favor of" +
                " #{target_name.search_name} by #{@user.login} on " +
                Time.now.to_formatted_s(:db) + comment_join + @comment)
              if @name.save_if_changed(@user,
                :log_name_deprecated, { :user => @user.login,
                :other => target_name.display_name }, current_time, true)
                @name.add_editor(@user)
              end
              redirect_to(:action => 'show_name', :id => @name.id)
            end
end
        end
      end
    end
  end

  def approve_name
    if verify_user()
      @name = Name.find(params[:id])
      @approved_names = @name.approved_synonyms
      if request.method == :post
        now = Time.now
        if params[:deprecate][:others] == '1'
          for n in @name.approved_synonyms
            n.change_deprecated(true)
            if n.save_if_changed(@user,
              :log_name_deprecated, { :user => @user.login,
              :other => @name.search_name }, now, true)
              n.add_editor(@user)
            end
          end
        end
        @name.change_deprecated(false)
        comment = (params[:comment] && params[:comment][:comment] ?
           params[:comment][:comment] : "").strip
        comment_join = comment == "" ? "." : ":\n"
        @name.prepend_notes("Approved by #{@user.login} on " +
          Time.now.to_formatted_s(:db) + comment_join + comment)
        if @name.save_if_changed(@user, :log_approved_by, { :user => @user.login }, now, true)
          @name.add_editor(@user)
        end
        redirect_to(:action => 'show_name', :id => @name.id)
      end
    end
  end

  # name_index/create_species_list -> bulk_name_edit
  def bulk_name_edit
    if verify_user()
      @list_members = nil
      @new_names    = nil
      if request.method == :post
        list = params[:list][:members].squeeze(" ") # Get rid of extra whitespace while we're at it
        construct_approved_names(list, params[:approved_names], @user)
        sorter = setup_sorter(params, nil, list)
        if sorter.only_single_names
          sorter.create_new_synonyms()
          flash_notice :name_bulk_success.t
          redirect_to(:controller => 'observer', :action => 'list_rss_logs')
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
    @synonym_data = []
    synonym = @name.synonym
    if synonym
      for n in synonym.names
        if n != @name
          syn_locs = name_locs(n.id)
          for l in syn_locs
            unless locs.member?(l)
              locs.push(l)
            end
          end
        end
      end
    end
    @map = nil
    @header = nil
    if locs.length > 0
      @map = make_map(locs)
      @header = "#{GMap.header}\n#{finish_map(@map)}"
    end
  end

  def email_tracking
    name_id = params[:id]
    if verify_user()
      @notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name_id, @user.id)
      if request.method == :post
        name = Name.find(name_id)
        case params[:commit]
        when :app_enable.l, :app_update.l
          note_template = params[:notification][:note_template]
          note_template = nil if note_template == ''
          if @notification.nil?
            @notification = Notification.new(:flavor => :name, :user => @user, :obj_id => name_id,
                :note_template => note_template)
            flash_notice(:email_tracking_now_tracking.t(:name => name.display_name))
          else
            @notification.note_template = note_template
            flash_notice(:email_tracking_updated_messages.t)
          end
          @notification.save
        when :app_disable.l
          @notification.destroy()
          flash_notice(:email_tracking_no_longer_tracking.t(:name => name.display_name))
        end
        redirect_to(:action => 'show_name', :id => name_id)
      else
        @name = Name.find(name_id)
        if [:Family, :Order, :Class, :Phylum, :Kingdom, :Group].member?(@name.rank)
          flash_warning(:email_tracking_enabled_only_for.t(:name => @name.display_name, :rank => @name.rank))
        end
        if @notification
          @note_template = @notification.note_template
        else
          mailing_address = @user.mailing_address.strip
          mailing_address = ':mailing_address' if mailing_address == ''
          @note_template = :email_tracking_note_template.l(
            :species_name => @name.text_name,
            :mailing_address => mailing_address,
            :users_name => @user.legal_name
          )
        end
      end
    end
  end

  # Form to compose email for the authors/reviewers
  # Linked from: show_name
  # Inputs:
  #   params[:id]
  # Outputs: @name
  def author_request
    @name = Name.find(params[:id])
  end

  # Sends email to the authors/reviewers
  # Linked from: author_request
  # Inputs:
  #   params[:id]
  #   params[:email][:subject]
  #   params[:email][:content]
  # Success:
  #   Redirects to show_name.
  #
  # TODO: Use queued_email mechanism
  def send_author_request
    sender = @user
    name = Name.find(params[:id])
    subject = params[:email][:subject]
    content = params[:email][:content]
    for receiver in name.authors + UserGroup.find_by_name('reviewers').users
      AccountMailer.deliver_author_request(sender, receiver, name, subject, content)
    end
    flash_notice(:request_success.t)
    redirect_to(:action => 'show_name', :id => name.id)
  end

  # Form to adjust permissions for a user with respect to a project
  # Linked from: show_name, author_request email
  # Inputs:
  #   params[:id]
  #   params[:add]
  #   params[:remove]
  # Success:
  #   Redraws itself.
  # Failure:
  #   Renders show_name.
  #   Outputs: @name, @authors, @users
  def review_authors
    @name = Name.find(params[:id])
    if verify_user()
      @authors = @name.authors
      if @authors.member?(@user) or @user.in_group('reviewers')
        @users = User.find(:all, :order => "login, name")
        new_author = params[:add] ?  User.find(params[:add]) : nil
        if new_author and not @name.authors.member?(new_author)
          @name.add_author(new_author)
          flash_notice("Added #{new_author.legal_name}")
          # Should send email as well
        end
        old_author = params[:remove] ? User.find(params[:remove]) : nil
        if old_author
          @name.remove_author(old_author)
          flash_notice("Removed #{old_author.legal_name}")
          # Should send email as well
        end
      else
        flash_error(:review_authors_denied.t)
        redirect_to(:action => 'show_name', :id => @name.id)
      end
    end
  end

  def eol_data(review_status_list, last_name=nil)
    rsl_list = review_status_list.join("', '")
    conditions = "review_status IN ('#{rsl_list}') and gen_desc is not null and ok_for_export = 1"
    conditions += " and text_name > '#{last_name}'" if last_name
    names = Name.find(:all, :conditions => conditions, :order => "search_name")
    
    image_data = Name.connection.select_all %(
      SELECT name_id, image_id, observation_id, images.user_id, images.license_id, images.created
      FROM names, observations, images_observations, images
      WHERE names.id = observations.name_id
      AND observations.id = images_observations.observation_id
      AND observations.vote_cache >= 2.4
      AND images_observations.image_id = images.id
      AND images.quality in ('medium', 'high')
      ORDER BY observations.vote_cache
    )
    @image_data = {}
    @users = {}
    @licenses = {}
    for row in image_data
      name_id = row['name_id'].to_i
      image_datum = [row['image_id'], row['observation_id'], row['user_id'], row['license_id'], row['created']]
      @image_data[name_id] = [] unless @image_data[name_id]
      @image_data[name_id].push(image_datum)
      user_id = row['user_id'].to_i
      @users[user_id] = User.find(user_id).legal_name unless @users[user_id]
      license_id = row['license_id'].to_i
      @licenses[license_id] = License.find(license_id).url unless @licenses[license_id]
    end
    @names = []
    @authors = {} # Maps name.id -> lists of user.ids
    @authors.default = []
    for n in names
      if @image_data[n.id] or n.has_any_notes?
        @names.push(n)
        author_data = Name.connection.select_all("SELECT user_id FROM authors_names WHERE name_id = #{n.id}")
        authors = author_data.map {|d| d['user_id']}
        authors = [n.user_id] if authors == []
        @authors[n.id] = authors
        for author in authors
          author_id = author.to_i
          unless @users[author_id]
            @users[author_id] = User.find(author_id).legal_name
          end
        end
        @authors[n.id] = (authors.map {|id| @users[id.to_i]}).join(', ')
        unless n.license_id.nil? or @licenses[n.license_id]
          @licenses[n.license_id] = n.license.url
        end
      end
    end
  end

  def eol
    headers["Content-Type"] = "application/xml"
    @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
    @start = Time.now()
    eol_data(['unvetted', 'vetted'], params[:last_name])
    render(:action => "eol", :layout => false)
  end

  # Show the data getting sent to EOL
  def eol_preview
    eol_data(['unvetted', 'vetted'])
  end

  # Show the data not getting sent to EOL
  def eol_need_review
    eol_data(['unreviewed'])
    @title = :eol_need_review_title.t
    render(:action => 'eol_preview')
  end

################################################################################

  # Finds the intended name and if another matching name exists,
  # then ensure it is mergable.  Returns [target_name, other_name]
  # It is expected that changes be made to target_name, and that
  # other_name gets deleted after the merge(?)
  def find_target_names(id_str, text_name, author, all_notes)

    # Look up name we're changing first (by id).
    page_name = nil
    id = nil
    if id_str
      id = id_str.to_i
      page_name = Name.find(id)
    end

    # Look for other Names that match the new name.  (Take first if several.)
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

    # Return Name we're changing and matching Name.
    result = [page_name, other_name]

    # If there is a matching Name, which do we actually want to change?
    if other_name
      if other_name.has_any_notes?
        # If both Names have notes we don't know how to merge, so throw an error.
        if !blank_notes(all_notes) && (other_name.all_notes != all_notes)
          raise :runtime_name_in_use_with_notes.t(:name => text_name, :other => other_name.display_name)
        end
        # Only the *other* name has notes -- make changes to that one instead.
        result = [other_name, page_name]
      elsif page_name.nil?
        # If we're trying to create a new Name but find a matching one already exists, return that Name.
        result = [other_name, page_name]
      elsif !page_name.has_any_notes?
        # Neither has notes, so we need another criterion
        if page_name.deprecated and !other_name.deprecated # Prefer valid names
          result = [other_name, page_name]
        # If both are deprecated, take the one with longer history of changes.
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
        if name.save_if_changed(user, :log_deprecated_by, { :user => user.login }, Time.now, true)
          name.add_editor(@user)
        end
      rescue RuntimeError => err
        flash_error(err.to_s)
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
