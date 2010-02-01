#
#  Views: ("*" - login required, "R" - root required)
#     name_index          List of results of index/search.
#     all_names           Alphabetical list of all names, used or otherwise.
#     observation_index   Alphabetical list of names people have seen.
#     name_search         Seach for string in name, notes, etc.
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
#
#  Admin Tools:
#   R cleanup_versions
#   R do_maintenance
#
#  Helpers:
#    name_locs(name_id)             List of locs where name has been observed.
#    find_target_names(...)         (used by edit_name)
#    deprecate_synonym(name)        (used by change_synonyms)
#    check_for_new_synonym(...)     (used by change_synonyms)
#    dump_sorter(sorter)            Error diagnostics for change_synonyms.
#
################################################################################

class NameController < ApplicationController
  before_filter :login_required, :except => [
    :advanced_search,
    :all_names,
    :authored_names,
    :auto_complete_name,
    :eol,
    :eol_preview,
    :map,
    :name_index,
    :name_search,
    :names_by_author,
    :names_by_editor,
    :needed_descriptions,
    :next_name,
    :observation_index,
    :prev_name,
    :show_name,
    :show_past_name,
  ]

  before_filter :disable_link_prefetching, :except => [
    :approve_name,
    :bulk_name_edit,
    :change_synonyms,
    :create_name,
    :deprecate_name,
    :edit_name,
    :show_name,
    :show_past_name,
  ]

  ##############################################################################
  #
  #  :section: Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def name_index
    query = find_or_create_query(:Name, :all, :by => :name)
    @title = :name_index_name_index.t
    show_selected_names(query)
  end

  # Display list of all (correctly-spelled) names in the database.
  def all_names
    query = create_query(:Name, :all, :by => :name)
    @title = :name_index_name_index.t
    show_selected_names(query)
  end

  # Display list of names that have observations.
  def observation_index
    query = create_query(:Name, :with_observations)
    @title = :name_index_observation_index.t
    show_selected_names(query)
  end

  # Display list of names that have authors.
  def authored_names
    @title = :authored_names_title.t
    query = create_query(:Name, :with_authors)
    show_selected_names(query) do |name|
      # Add some extra fields to the index.
      [ name.authors.map(&:login).join(', '),
        name.note_status.map(&:to_s).join('/'),
        name.review_status.t ]
    end
  end

  # Display list of names that a given user is author on.
  def names_by_author
    user = User.find(params[:id])
    @title = :names_by_author_title.t(:name => user.legal_name)
    @error = :names_by_author_error.t(:name => user.legal_name)
    query = create_query(:Name, :by_author, :user => user)
    show_selected_names(query)
  end

  # Display list of names that a given user is editor on.
  def names_by_editor
    user = User.find(params[:id])
    @title = :names_by_editor_title.t(:name => user.legal_name)
    @error = :names_by_editor_error.t(:name => user.legal_name)
    query = create_query(:Name, :by_editor, :user => user)
    show_selected_names(query)
  end

  # Display list of the most popular 100 names that don't have descriptions.
  def needed_descriptions
    data = Name.connection.select_rows %(
      SELECT names.id, name_counts.count
      FROM names LEFT OUTER JOIN draft_names ON names.id = draft_names.name_id,
           (SELECT count(*) AS count, name_id
            FROM observations group by name_id) AS name_counts
      WHERE names.id = name_counts.name_id
        AND names.rank = 'Species'
        AND (names.gen_desc IS NULL OR names.gen_desc = '')
        AND name_counts.count > 1
        AND draft_names.name_id IS NULL
        AND CURRENT_TIMESTAMP - modified > #{1.week.to_i}
      ORDER BY name_counts.count DESC, names.search_name ASC
      LIMIT 100
    )
    @title = :needed_descriptions_title.t
    @help  = :needed_descriptions_help
    query = create_query(:Name, :in_set, :ids => data.map(&:first))
    show_selected_names(query, 100) do |name|
      # Add number of observations (parenthetically).
      row = data.select {|id,count| id == name.id}.first
      row ? "(#{count} #{:observations.t})" : ''
    end
  end

  # Display list of names that match a string.
  def name_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       name = Name.safe_find(pattern)
      redirect_to(:action => 'show_name', :id => name.id)
    else
      query = create_query(:Name, :pattern, :pattern => pattern)
      @title = :name_index_matching.t(:pattern => pattern)
      show_selected_names(query)
    end
  end

  # Displays list of advanced search results.
  def advanced_search
    begin
      query = find_query(:Name)
      @title = :advanced_search_title.t
      show_selected_names(query)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search_form')
    end
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_names(query, num_per_page=50)
    store_query(query)
    show_index_of_objects(query,
      :action => 'list_names',
      :letters => 'names.text_name',
      :num_per_page => num_per_page
    )
  end

  ################################################################################
  #
  #  :section: Show Name
  #
  ################################################################################

  # show_name.rhtml
  def show_name
    # Rough testing showed implementation without synonyms takes .23-.39 secs.
    # elapsed_time = Benchmark.realtime do

    pass_query_params
    store_location
    store_query
    @name = Name.find(params[:id])
    update_view_stats(@name)
    @past_name = @name.versions.latest
    @past_name = @past_name.previous if @past_name
    @parents = @name.parents

    # Is @user a reviewer?
    @is_reviewer = is_reviewer

    # Is @user "interested" in this name?
    @interest = nil
    @interest = Interest.find_by_user_id_and_object_type_and_object_id(@user.id,
                            'Name', @name.id) if @user

    # Get list of drafts for this name.
    @existing_drafts = DraftName.find_all_by_name_id(@name.id,
                            :include => :project, :order => "projects.title")
    @existing_drafts = nil if @existing_drafts == []

    # Get list of projects user is part of.
    @user_projects = nil
    if @user and !@existing_drafts
      @user_projects = @user.user_groups.map(&:project).reject(&:nil?).sort_by(&:title)
      @user_projects = nil if @user_projects == []
    end

    # Create query for immediate children.
    @children_query = create_query(:Name, :children, :name => @name)

    # Create search queries for observation lists.
    @consensus_query = create_query(:Observation, :of_name, :name => @name)
    @synonym_query = create_query(:Observation, :of_name, :name => @name,
                                  :synonyms => :exclusive)
    @other_query = create_query(:Observation, :of_name, :name => @name,
                                :synonyms => :all, :nonconsensus => :exclusive)

    # Paginate each of the sections independently.
    @children_pages  = paginate_numbers(:children_page, 24)
    @consensus_pages = paginate_numbers(:consensus_page, 12)
    @synonym_pages   = paginate_numbers(:synonym_page, 12)
    @other_pages     = paginate_numbers(:other_page, 12)

    @children_data  = @children_query.paginate(@children_pages)
    @consensus_data = @consensus_query.paginate(@consensus_pages)
    @synonym_data   = @synonym_query.paginate(@synonym_pages)
    @other_data     = @other_query.paginate(@other_pages)

    # end
    # logger.warn("show_name took %s\n" % elapsed_time)
  end

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status
    pass_query_params
    id = params[:id]
    if is_reviewer?
      Name.find(id).update_review_status(params[:value])
    end
    redirect_to(:action => 'show_name', :id => id, :params => query_params)
  end

  # Callback to let reviewers change the export status of a Name from the
  # show_name page.
  def set_export_status
    id = params[:id]
    if is_reviewer
      name = Name.find(id)
      name.ok_for_export = params[:value]
      name.save
    end
    redirect_to(:action => 'show_name', :id => id)
  end

  # Show past version of Name.  Accessible only from show_name page.
  def show_past_name
    pass_query_params
    store_location
    @name = Name.find(params[:id])
    @past_name = Name.find(params[:id])
    @past_name.revert_to(params[:version].to_i)
    @other_versions = @name.versions.reverse
  end

  # Go to next observation: redirects to show_observation.
  def next_name
    name = Name.find(params[:id])
    redirect_to_next_object(:next, name)
  end

  # Go to previous name: redirects to show_name.
  def prev_name
    name = Name.find(params[:id])
    redirect_to_next_object(:prev, name)
  end

  ##############################################################################
  #
  #  :section: Create and Edit
  #
  ##############################################################################

  # Create a new name; accessible from name indexes.
  def create_name
    pass_query_params
    if request.method != :post
      @name = Name.new
      @licenses = License.current_names_and_ids
      @name.rank = :Species
      @can_make_changes = true
    else
      begin
        text_name = params[:name][:text_name].to_s.strip_squeeze
        author    = params[:name][:author].to_s.strip_squeeze
        rank      = params[:name][:rank].to_s

        # Grab all the notes sections: general description, look-alikes, etc.
        all_notes = {}
        for f in Name.all_note_fields
          all_notes[f] = params[:name][f]
        end

        # Classification is no longer part of all_notes.
        classification = params[:name][:classification].to_s
        classification = Name.validate_classification(rank, classification)

        # Look up name.
        name_str  = text_name
        matches   = nil
        if author != ''
          matches = Name.find_all_by_text_name_and_author(text_name, author)
          name_str += " #{author}"
        else
          matches = Name.find_all_by_text_name(text_name)
        end

        # Name already exists.
        if matches.length > 0
          flash_error(:name_create_already_exists.t(:name => name_str))
          name = matches[0]

        # Create name.
        else
          # This returns a list of names starting with genus, on down to the
          # given name: genus, species, variety, ...
          names = Name.names_from_string(name_str)
          name = names.last
          raise :runtime_unable_to_create_name.t(:name => name_str) if !name

          name.rank     = rank # Not quite right since names_from_string sets rank too
          name.change_text_name(text_name, author, rank) # Validates parse(??)
          name.citation = params[:name][:citation]
          name.classification = classification

          # Set all the "notes" fields.
          if !notes_all_blank?(all_notes)
            name.all_notes = all_notes
            name.license_id = params[:name][:license_id]
          else
            name.license_id = nil
          end

          # Save any changed names.
          for n in names
            save_name(n, :log_name_updated) if n
          end
        end

      # Anything causing changes not to get saved ends up here.
      rescue RuntimeError => err
        @name = Name.new
        flash_error(err.to_s) if !err.nil?
        flash_object_errors(@name)
        @name.attributes = params[:name]
        @licenses = License.current_names_and_ids()
        @can_make_changes = true

      else
        # If no errors occurred, changes must've been made successfully.
        redirect_to(:action => 'show_name', :id => name.id,
                    :params => query_params)
      end
    end
  end

  # Make changes to name; accessible from show_name page.
  def edit_name
    pass_query_params
    any_errors = false
    @name = Name.find(params[:id])
    @licenses = License.current_names_and_ids(@name.license)

    # Initialize misspelling fields.  Start with just a checkbox.  If user
    # checks it, it guesses the correct spelling.  If it fails to guess, it
    # flashes an error, and subsequent times through it presents a text field
    # (with auto-completer).
    @misspelling = false
    if @name.is_misspelling? || (params[:name] && params[:name][:misspelling] == '1')
      @name.misspelling = true
      @name_primer = Name.primer
    end

    # Only allowed to make substantive changes it you own all the references
    # to it.  I think checking that the user owns all the namings that use it
    # is correct.  Maybe we should also check observations?  But the
    # observation simply caches the winning naming's name.  Actually not
    # necessarily: obs might use the accepted name if the winning name is
    # deprecated.  Hmmm, I'll check it to be safe.
    @can_make_changes = true
    if is_in_admin_mode?
      for obj in @name.namings + @name.observations
        if obj.user_id != @user.id
          @can_make_changes = false
          break
        end
      end
    end

    if request.method == :post
      begin
        text_name = params[:name][:text_name].to_s.strip_squeeze
        author    = params[:name][:author].to_s.strip_squeeze
        rank      = params[:name][:rank].to_s

        # Grab all the notes sections: general description, look-alikes, etc.
        all_notes = {}
        for f in Name.all_note_fields
          all_notes[f] = params[:name][f]
        end

        # It is possible to change a Name's name if no one is using it yet
        # (or the user owns all uses of it).  This looks up the name we're
        # trying to change it to.  If it already exists, it ensures that they
        # are mergable, then decides which to merge into and which to delete.
        # Make changes to @name, delete old_name.  (Raises a RuntimeError if
        # we can't do the merge.)
        @name, old_name = find_target_name(@name, text_name, author, all_notes)

        # Merge authors.
        if author == ''
          author = @name.author.to_s
          # If merging another name, try its author.
          if author == '' && old_name
            author = old_name.author.to_s
          end
        end

        # Merge text_names.
        if text_name == ''
          text_name = @name.text_name
        end
        @name.change_text_name(text_name, author, rank, :save_parents)

        # Merge citations.
        citation = params[:name][:citation].to_s.strip_squeeze
        if citation == ''
          citation = @name.citation.to_s
          if citation == '' && old_name
            citation = old_name.citation.to_s
          end
        end
        @name.citation = citation

        # Merge classifications.
        classification = Name.validate_classification(rank,
                                          params[:name][:classification].to_s)
        if classification == ''
          classification = @name.classification.to_s
          if classification == '' && old_name
            classification = old_name.classification.to_s
          end
        end
        @name.classification = classification

        # Merge notes.
        if notes_all_blank?(all_notes)
          all_notes = @name.all_notes
          if notes_all_blank?(all_notes) && old_name
            all_notes = old_name.all_notes
          end
        end
        @name.all_notes = all_notes

        # Save change to license_id.
        if @name.has_any_notes?
          @name.license_id = params[:name][:license_id]
        else
          # (Clear it if there are no notes.)
          @name.license_id = nil
        end

        # Let user call this name a misspelling.
        @misspelling = (params[:name][:misspelling].to_s == '1')
        @correct_spelling = params[:name][:correct_spelling]
        if !update_correct_spelling(@name, @misspelling, @correct_spelling)
          any_errors = true
        end

        # If substantive changes are made by a reviewer, call this act a
        # "review", even though they haven't actually changed the review
        # status.  If substantive changes are made by a non-reviewer,
        # this will revert status to unreviewed.
        if @name.save_version?
          @name.update_review_status(@name.review_status)
        end

        if save_name(@name, :log_name_updated)
          # nothing else to do
        elsif @name.errors.length > 0
          raise :runtime_unable_to_save_changes.t
        end

        # Merge old_name's attachments to the new name, then destroy it.
        @name.merge_names(old_name) if old_name

      rescue RuntimeError => err
        # Anything causing changes not to get saved ends up here.
        flash_error(err.to_s) if !err.nil?
        flash_object_errors(@name)
        @name.attributes = params[:name]

      else
        if !any_errors
          # If no errors occurred, changes must've been made successfully.
          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        end
      end
    end
  end

  # Looks up the name we're trying to change this one to.  If it already
  # exists, ensure that they're mergable, and decide which one we want to keep.
  # Returns both names; make changes to the first, delete the second.
  def find_target_name(page_name, text_name, author, all_notes)

    # Look for other Names that match the new name.  (Take first if several.)
    old_name = nil
    if author != ''
      matches = Name.find_all_by_text_name_and_author(text_name, author)
    else
      matches = Name.find_all_by_text_name(text_name)
    end
    for m in matches
      if m.id != page_name.id
        old_name = m   # (Just take the first one.)
        break
      end
    end

    # If there is a matching Name, which do we actually want to change?
    result = [page_name, old_name]
    if old_name
      if old_name.has_any_notes?
        # If both Names have notes we don't know how to merge, so throw an error.
        if !notes_all_blank?(all_notes) && (old_name.all_notes != all_notes)
          raise :runtime_name_in_use_with_notes.t(:name => text_name,
                                              :other => old_name.display_name)
        end
        # Only the old name has notes -- make changes to that one instead.
        result = [old_name, page_name]
      elsif !page_name.has_any_notes?
        # Neither has notes, so we need another criterion. Prefer valid names.
        if page_name.deprecated and !old_name.deprecated
          result = [old_name, page_name]
        # If both are deprecated, take the one with longer history of changes.
        elsif (old_name.deprecated == page_name.deprecated) and
              (old_name.version >= page_name.version)
          result = [old_name, page_name]
        end
      end
    end
    result
  end

  # Update the misspelling status.
  #
  # name::             Name whose status we're changing.
  # misspelling::      Boolean: is the "this is a misspelling" box checked?
  # correct_spelling:: String: the correct name, as entered by the user.
  #
  # 1) If the checkbox is unchecked, it clears all the misspelling stuff.
  # 2) If the checkbox is checked and a name is entered, it validates it.
  # 3) If the checkbox is checked but no name entered, it tries to guess.
  #
  # There are no side-effects (except that the "correct name" is marked as "not
  # a misspelling").  All changes are made (but not saved) to +name+.  It
  # returns true if everything went well.  If anything at all fails, it clears
  # all the misspelling stuff in +name+, prints an error message and makes the
  # user fix whatever it is.
  #
  def update_correct_spelling(name, misspelling, correct_spelling)
    result = true

    # Clear status if checkbox unchecked.
    if !misspelling
      name.misspelling = false
      name.correct_spelling = nil

    else
      name2 = nil

      # User has told us what the correct spelling should be.  Make sure
      # this is a valid name!
      if correct_spelling.to_s != ''
        self.misspelling = true
        name2 = Name.find_by_search_name(correct_spelling)
        name2 ||= Name.find_by_text_name(correct_spelling)
        if !name2
          flash_error(:form_names_misspelling_bad.t)
        elsif result.id == self.id
          flash_error(:form_names_misspelling_same.t)
        end

        # User just checked the box, but didn't tell us the correct
      else
        # answer -- let's see if we can guess it before complaining.
        begin
          name2 = name.guess_correct_spelling
        rescue => err
          flash_error(err)
        end
      end

      # Found a good name: make that the correct spelling for this one.
      if name2
        name.misspelling = true
        name.correct_spelling = name2
        name.merge_synonyms(name2)
        name.change_deprecated(true)

        # Make sure the "correct" name isn't also a misspelled name!
        if name2.is_misspelling?
          name2.correct_spelling = nil
          name2.log(:log_name_unmisspelled, :other => name.display_name)
          name2.save
        end

      # If anything at all goes wrong, clear the misspelling and make the
      # user fix whatever it was.
      else
        name.misspelling = false
        name.correct_spelling = nil
        result = false
      end
    end

    return result
  end

  # Return true if all notes are blank / missing.
  def notes_all_blank?(note_hash)
    result = true
    for key, value in note_hash
      if value.to_s != ''
        result = false
        break
      end
    end
    result
  end

  ################################################################################
  #
  #  :section: Synonymy
  #
  ################################################################################

  # Form accessible from show_name that lets a user review all the synonyms
  # of a name, removing others, writing in new, etc.
  def change_synonyms
    pass_query_params
    @name = Name.find(params[:id])
    @list_members     = nil
    @new_names        = nil
    @synonym_name_ids = []
    @synonym_names    = []
    @deprecate_all    = '1'
    if request.method == :post
      list = params[:synonym][:members].strip_squeeze
      deprecate = (params[:deprecate][:all] == '1')

      # Create any new names that have been approved.
      construct_approved_names(list, params[:approved_names], deprecate)

      # Parse the write-in list of names.
      sorter = NameSorter.new
      sorter.sort_names(list)
      sorter.append_approved_synonyms(params[:approved_synonyms])

      # Are any names unrecognized (only unapproved names will still be
      # unrecognized at this point) or ambiguous?
      if !sorter.only_single_names
        dump_sorter(sorter)
      # Has the user NOT had a chance to choose from among the synonyms of any
      # names they've written in?
      elsif !sorter.only_approved_synonyms
        flash_notice :name_change_synonyms_confirm.t
      else
        now = Time.now
        synonym = @name.synonym

        # Create synonym and add this name to it if this name not already
        # associated with a synonym.
        if !synonym
          synonym = Synonym.new
          synonym.created = now
          synonym.save
          @name.synonym = synonym
          @name.save
          Transaction.post_synonym(
            :id => synonym
          )
          Transaction.put_name(
            :id          => @name,
            :set_synonym => synonym
          )
        end

        # Go through list of all synonyms for this name and written-in names.
        # Exclude any names that have un-checked check-boxes: newly written-in
        # names will not have a check-box yet, names written-in in previous
        # attempt to submit this form will have checkboxes and therefore must
        # be checked to proceed -- the default initial state.
        proposed_synonyms = params[:proposed_synonyms] || {}
        for n in sorter.all_synonyms
          # Synonymize all names that have been checked, or that don't have
          # checkboxes.
          if proposed_synonyms[n.id.to_s] != '0'
            if n.synonym_id != synonym.id
              synonym.transfer(n)
              Transaction.put_name(
                :id          => n,
                :set_synonym => synonym
              )
            end
          end
        end

        # De-synonymize any old synonyms in the "existing synonyms" list that
        # have been unchecked.  This creates a new synonym to connect them if
        # there are multiple unchecked names -- that is, it splits this
        # synonym into two synonyms, with checked names staying in this one,
        # and unchecked names moving to the new one.
        check_for_new_synonym(@name, synonym.names, params[:existing_synonyms] || {})

        # We're done modifying the synonym now.
        synonym.modified = now
        synonym.save
        success = true

        # Deprecate everything if that check-box has been marked.
        if deprecate
          for n in sorter.all_names
            if !deprecate_synonym(n)
              # Already flashed error message.
              success = false
            end
          end
        end

        if success
          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        else
          flash_object_errors(@name)
          flash_object_errors(@name.synonym)
        end
      end

      @list_members     = sorter.all_line_strs.join("\r\n")
      @new_names        = sorter.new_name_strs.uniq
      @synonym_name_ids = sorter.all_synonyms.map(&:id)
      @synonym_names    = @synonym_name_ids.map {|id| Name.find(id)}
      @deprecate_all    = params[:deprecate][:all]
    end
  end

  # Form accessible from show_name that lets the user deprecate a name in favor
  # of another name. 
  def deprecate_name
    pass_query_params

    # Unit tests sometimes forget to supply required args.
    if TESTING
      params[:proposed]    ||= {}
      params[:comment]     ||= {}
      params[:chosen_name] ||= {}
      params[:is]          ||= {}
    end

    @name    = Name.find(params[:id])
    @what    = params[:proposed][:name].to_s.strip_squeeze
    @comment = params[:comment][:comment].to_s.strip_squeeze

    @list_members     = nil
    @new_names        = []
    @synonym_name_ids = []
    @synonym_names    = []
    @deprecate_all    = '1'
    @names            = []
    @misspelling      = params[:is][:misspelling] == '1'
    @name_primer      = Name.primer

    if request.method == :post
      if @what == ''
        flash_error :name_deprecate_must_choose.t

      else
        # Find the chosen preferred name.
        if params[:chosen_name][:name_id]
          @names = [Name.find(params[:chosen_name][:name_id])]
        else
          @names = Name.find_names(@what)
        end
        if @names.length == 0 &&
          new_name = create_needed_names(params[:approved_name], @what)
          @names = [new_name]
        end
        target_name = @names.first

        # If written-in name matches uniquely an existing name:
        if target_name && @names.length == 1
          now = Time.now

          # Merge this name's synonyms with the preferred name's synonyms.
          @name.merge_synonyms(target_name)

          # Change target name to "undeprecated".
          target_name.change_deprecated(false)
          save_name(target_name, :log_name_approved)

          # Change this name to "deprecated", set correct spelling, add note.
          @name.change_deprecated(true)
          if @misspelling
            @name.misspelling = true
            @name.correct_spelling = target_name
          end
          comment_join = @comment == "" ? "." : ":\n"
          @name.prepend_notes("Deprecated in favor of" +
            " #{target_name.search_name} by #{@user.login} on " +
            Time.now.to_formatted_s(:db) + comment_join + @comment)
          save_name(@name, :log_name_deprecated)

          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        end

      end # @what
    end # :post
  end

  # Form accessible from show_name that lets a user make call this an accepted
  # name, possibly deprecating its synonyms at the same time.
  def approve_name
    pass_query_params
    @name = Name.find(params[:id])
    @approved_names = @name.approved_synonyms
    if request.method == :post
      now = Time.now
      if params[:deprecate][:others] == '1'
        for n in @name.approved_synonyms
          n.change_deprecated(true)
          n.log(:log_name_deprecated, :other => @name.search_name)
          n.save
        end
      end
      @name.change_deprecated(false)
      comment = (params[:comment] && params[:comment][:comment] ?
         params[:comment][:comment] : "").strip
      comment_join = comment == "" ? "." : ":\n"
      @name.prepend_notes("Approved by #{@user.login} on " +
        Time.now.to_formatted_s(:db) + comment_join + comment)
      @name.log(:log_approved_by)
      @name.save
      redirect_to(:action => 'show_name', :id => @name.id,
                  :params => query_params)
    end
  end

  # Helper used by change_synonyms.  Deprecates a single name.  Returns true
  # if it worked.  Flashes an error and returns false if it fails for whatever
  # reason.
  def deprecate_synonym(name)
    result = true
    unless name.deprecated
      begin
        name.change_deprecated(true)
        name.log(:log_deprecated_by)
        if !name.save
          flash_object_errors(name)
          result = false
        end
      rescue RuntimeError => err
        flash_error(err.to_s)
        result = false
      end
    end
    return result
  end

  # If changing the synonyms of a name that already has synonyms, the user is
  # presented with a list of "existing synonyms".  This is a list of check-
  # boxes.  They all start out checked.  If the user unchecks one, then that
  # name is removed from this synonym.  If the user unchecks several, then a
  # new synonym is created to synonymize all those names.
  def check_for_new_synonym(name, candidates, checks)
    new_synonym_members = []
    # Gather all names with un-checked checkboxes.
    for n in candidates
      if (name != n) && (checks[n.id.to_s] == '0')
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
        Transaction.put_name(
          :id          => n,
          :set_synonym => new_synonym
        )
      end
    elsif len == 1
      name = new_synonym_members.first
      name.clear_synonym
      Transaction.put_name(
        :id          => name,
        :set_synonym => 0
      )
    end
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
    logger.warn("\nSynonym names:")
    for n in sorter.all_synonyms.map(&:id)
      logger.warn(n)
    end
  end

  ##############################################################################
  #
  #  :section: EOL Feed
  #
  ##############################################################################

  # Send stuff to eol.
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

  # Gather data for EOL feed.
  #
  # @licenses::   Hash: ???
  # @authors::    Hash: ???
  # @users::      Hash: ???
  # @names::      Hash: ???
  # @image_data:: Hash: ???
  #
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

  ################################################################################
  #
  #  :section: Other Stuff
  #
  ################################################################################

  # Utility accessible from a number of name pages (e.g. indexes and
  # show_name?) that lets you enter a whole list of names, together with
  # synonymy, and create them all in one blow. 
  def bulk_name_edit
    @list_members = nil
    @new_names    = nil
    if request.method == :post
      list = params[:list][:members].strip_squeeze
      construct_approved_names(list, params[:approved_names])
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

  # Draw a map of all the locations where this name has been observed.
  def map
    pass_query_params
    @name = Name.find(params[:id])
    @query = create_query(:Location, :with_observations_of_name, :name => @name)
    @locations = @query.results
  end

  # Form accessible from show_name that lets a user setup tracker notifications
  # for a name.
  def email_tracking
    pass_query_params
    name_id = params[:id]
    @notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name_id, @user.id)

    # Initialize form.
    if request.method != :post
      @name = Name.find(name_id)
      if Name.ranks_above_genus.member?(@name.rank)
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

    # Submit form.
    else
      name = Name.find(name_id)
      case params[:commit]
      when :app_enable.l, :app_update.l
        note_template = params[:notification][:note_template]
        note_template = nil if note_template == ''
        if @notification.nil?
          @notification = Notification.new(:flavor => :name, :user => @user,
              :obj_id => name_id, :note_template => note_template)
          flash_notice(:email_tracking_now_tracking.t(:name => name.display_name))
        else
          @notification.note_template = note_template
          flash_notice(:email_tracking_updated_messages.t)
        end
        @notification.save
      when :app_disable.l
        @notification.destroy
        flash_notice(:email_tracking_no_longer_tracking.t(:name => name.display_name))
      end
      redirect_to(:action => 'show_name', :id => name_id, :params => query_params)
    end
  end

  # Form to compose email for the authors/reviewers.  Linked from show_name.
  # TODO: Use queued_email mechanism.
  def author_request
    pass_query_params
    @name = Name.find(params[:id])
    if request.method == :post
      subject = params[:email][:subject] rescue ''
      content = params[:email][:content] rescue ''
      for receiver in @name.authors + UserGroup.find_by_name('reviewers').users
        AccountMailer.deliver_author_request(@user, receiver, @name, subject, content)
      end
      flash_notice(:request_success.t)
      redirect_to(:action => 'show_name', :id => @name.id,
                  :params => query_params)
    end
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
    pass_query_params
    @name = Name.find(params[:id])
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
      redirect_to(:action => 'show_name', :id => @name.id,
                  :params => query_params)
    end
  end
end
