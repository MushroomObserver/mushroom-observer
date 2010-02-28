#
#  Views: ("*" - login required, "R" - root required)
#     index_name          List of results of index/search.
#     list_names          Alphabetical list of all names, used or otherwise.
#     observation_index   Alphabetical list of names people have seen.
#     names_by_author     Alphabetical list of names authored by given user.
#     names_by_editor     Alphabetical list of names edited by given user.
#     name_search         Seach for string in name, notes, etc.
#     show_name           Show info about name.
#     show_past_name      Show past versions of name info.
#     prev_name           Show previous name in index.
#     next_name           Show next name in index.
#   * create_name         Create new name.
#   * edit_name           Edit name info.
#   * create_name_description
#   * edit_name_description
#   * destroy_name_description
#   * change_synonyms     Change list of synonyms for a name.
#   * deprecate_name      Deprecate name in favor of another.
#   * approve_name        Flag given name as "accepted" (others could be, too).
#   * bulk_name_edit      Create/synonymize/deprecate a list of names.
#     map                 Show distribution map.
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
    :authored_names,
    :auto_complete_name,
    :create_name,
    :create_name_description,
    :destroy_name_description,
    :edit_name,
    :edit_name_description,
    :eol,
    :eol_preview,
    :index_name,
    :map,
    :list_names,
    :name_search,
    :names_by_author,
    :names_by_editor,
    :needed_descriptions,
    :next_name,
    :observation_index,
    :prev_name,
    :show_name,
    :show_past_name,
    :test_index,
  ]

  before_filter :disable_link_prefetching, :except => [
    :approve_name,
    :bulk_name_edit,
    :change_synonyms,
    :create_name,
    :create_name_description,
    :deprecate_name,
    :edit_name,
    :edit_name_description,
    :show_name,
    :show_name_description,
    :show_past_name,
    :show_past_name_description,
  ]

  ##############################################################################
  #
  #  :section: Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name
    query = find_or_create_query(:Name, :all, :by => params[:by] || :name)
    query.params[:by] = params[:by] if params[:by]
    show_selected_names(query, :id => params[:id])
  end

  # Display list of all (correctly-spelled) names in the database.
  def list_names
    query = create_query(:Name, :all, :by => :name)
    show_selected_names(query)
  end

  # Display list of names that have observations.
  def observation_index
    query = create_query(:Name, :with_observations)
    show_selected_names(query)
  end

  # Display list of names that have authors.
  def authored_names
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
    @error = :names_by_author_error.t(:name => user.legal_name)
    query = create_query(:Name, :by_author, :user => user)
    show_selected_names(query)
  end

  # Display list of names that a given user is editor on.
  def names_by_editor
    user = User.find(params[:id])
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
    @help = :needed_descriptions_help
    query = create_query(:Name, :in_set, :ids => data.map(&:first),
                         :title => ":needed_descriptions_title")
    show_selected_names(query, :num_per_page => 100) do |name|
      # Add number of observations (parenthetically).
      row = data.select {|id,count| id == name.id}.first
      row ? "(#{count} #{:observations.t})" : ''
    end
  end

  # Display list of names that match a string.
  def name_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (name = Name.safe_find(pattern))
      redirect_to(:action => 'show_name', :id => name.id)
    else
      query = create_query(:Name, :pattern, :pattern => pattern)
      show_selected_names(query)
    end
  end

  # Displays list of advanced search results.
  def advanced_search
    begin
      query = find_query(:Name)
      show_selected_names(query)
    rescue => err
      flash_error(err)
      redirect_to(:controller => 'observer', :action => 'advanced_search_form')
    end
  end

  # Used to test pagination.
  def test_index
    query = find_query(:Name) or raise "Missing query: #{params[:q]}"
    if params[:test_anchor]
      @test_pagination_args = {:anchor => params[:test_anchor]}
    end
    show_selected_names(query, :num_per_page => params[:num_per_page].to_i)
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_names(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = { :action => 'list_names', :letters => 'names.text_name',
             :num_per_page => 50 }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name', :name.t],
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

    show_index_of_objects(query, args)
  end

  ################################################################################
  #
  #  :section: Show Name
  #
  ################################################################################

  # Show a Name, one of its NameDescription's, associated taxa, and a bunch of
  # relevant Observations.
  def show_name
    pass_query_params
    store_location
    clear_query_in_session

    # Load Name and NameDescription along with a bunch of associated objects.
    name_id = params[:id]
    desc_id = params[:desc]
    @name = Name.find(name_id, :include => [:user, :descriptions])
    desc_id = @name.description_id if desc_id.to_s == ''
    @description = NameDescription.find(desc_id, :include =>
                              [:authors, :editors, :license, :reviewer, :user])
    update_view_stats(@name)
    update_view_stats(@description)

    # Get a list of projects the user can create drafts for.
    @projects = @user && @user.projects_member.select do |project|
      !@name.descriptions.any? {|d| d.belongs_to_project?(project)}
    end

    # Get list of immediate parents.
    @parents = @name.parents

    # Create query for immediate children.
    @children_query = create_query(:Name, :of_children, :name => @name)

    # Create search queries for observation lists.
    @consensus_query = create_query(:Observation, :of_name, :name => @name)
    @synonym_query = create_query(:Observation, :of_name, :name => @name,
                                  :synonyms => :exclusive)
    @other_query = create_query(:Observation, :of_name, :name => @name,
                                :synonyms => :all, :nonconsensus => :exclusive)
    if @name.below_genus?
      @subtaxa_query = create_query(:Observation, :of_children, :name => @name,
                                                                :all => true)
    end

    # Paginate each of the sections independently.
    @children_pages  = paginate_numbers(:children_page, 24)
    @consensus_pages = paginate_numbers(:consensus_page, 12)
    @synonym_pages   = paginate_numbers(:synonym_page, 12)
    @other_pages     = paginate_numbers(:other_page, 12)
    if @subtaxa_query
      @subtaxa_pages = paginate_numbers(:subtaxa_page, 12)
    end

    args = { :include => [:name, :location, :user] }
    @children_data  = @children_query.paginate(@children_pages)
    @consensus_data = @consensus_query.paginate(@consensus_pages, args)
    @synonym_data   = @synonym_query.paginate(@synonym_pages, args)
    @other_data     = @other_query.paginate(@other_pages, args)
    if @subtaxa_query
      @subtaxa_data = @subtaxa_query.paginate(@subtaxa_pages, args)
    end
  end

  # Show just a NameDescription.
  def show_name_description
    store_location
    pass_query_params
    @description = NameDescription.find(params[:id], :include =>
      [:authors, :editors, :license, :reviewer, :user, {:name=>:descriptions}])
    @name = @description.name
    update_view_stats(@description)

    # Get a list of projects the user can create drafts for.
    @projects = @user && @user.projects_member.select do |project|
      !@name.descriptions.any? {|d| d.belongs_to_project?(project)}
    end
  end

  # Show past version of Name.  Accessible only from show_name page.
  def show_past_name
    pass_query_params
    store_location
    @name = Name.find(params[:id])
    @name.revert_to(params[:version].to_i)

    # Old correct spellings could have gotten merged with something else and no longer exist.
    if @name.is_misspelling?
      @correct_spelling = Name.connection.select_value %(
        SELECT display_name FROM names WHERE id = #{@name.correct_spelling_id}
      )
    else
      @correct_spelling = ''
    end
  end

  # Show past version of NameDescription.  Accessible only from
  # show_name_description page.
  def show_past_name_description
    pass_query_params
    store_location
    @description = NameDescription.find(params[:id])
    @description.revert_to(params[:version].to_i)
  end

  # Go to next name: redirects to show_name.
  def next_name
    redirect_to_next_object(:next, Name, params[:id])
  end

  # Go to previous name: redirects to show_name.
  def prev_name
    redirect_to_next_object(:prev, Name, params[:id])
  end

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status
    pass_query_params
    id = params[:id]
    desc = NameDescription.find(id)
    if is_reviewer?
      desc.update_review_status(params[:value])
    end
    redirect_to(:action => 'show_name', :id => desc.name_id,
                :params => query_params)
  end

  # Callback to let reviewers change the export status of a Name from the
  # show_name page.
  def set_export_status
    pass_query_params
    id = params[:id]
    desc = NameDescription.find(id)
    if is_reviewer?
      desc.ok_for_export = params[:value]
      desc.save_without_our_callbacks
    end
    redirect_to(:action => 'show_name', :id => desc.name_id,
                :params => query_params)
  end

  ##############################################################################
  #
  #  :section: Create and Edit
  #
  ##############################################################################

  # Create a new name; accessible from name indexes.
  def create_name
    store_location
    pass_query_params

    # Reder a blank form.
    if request.method != :post
      @name = Name.new
      @name.rank = :Species
      @can_make_changes = true

    else
      begin
        # Look up name to see if it already exists.
        text_name = params[:name][:text_name].to_s.strip_squeeze
        author    = params[:name][:author].to_s.strip_squeeze
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
          flash_error(:runtime_name_create_already_exists.t(:name => name_str))
          name = matches[0]

        # Create name.
        else
          # This returns a list of names starting with genus, on down to the
          # given name: genus, species, variety, ...
          names = Name.names_from_string(name_str)
          name = names.last
          raise(:runtime_unable_to_create_name.t(:name => name_str)) if !name

          # Not quite right since names_from_string sets rank too.  I don't
          # understand the subtlety of this. -JPH
          name.rank = rank = params[:name][:rank].to_s

          # This fills in the four name formats.
          name.change_text_name(text_name, author, rank)

          # I guess this is all that's left.
          name.citation = params[:name][:citation]

          # This saves this name, and genus/species above it as necessary.
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
        @can_make_changes = true

      else
        # If no errors occurred, either the name was created successfully, or
        # it already exists.  In either case redirect to the name in question.
        redirect_to(:action => 'show_name', :id => name.id,
                    :params => query_params)
      end
    end
  end

  # Make changes to name; accessible from show_name page.
  def edit_name
    store_location
    pass_query_params
    @name = Name.find(params[:id])

    # Initialize misspelling fields.  Start with just a checkbox.  If user
    # checks it, it guesses the correct spelling.  If it fails to guess, it
    # flashes an error, and subsequent times through it presents a text field
    # (with auto-completer).
    @misspelling = false
    if @name.is_misspelling? || (params[:name] && params[:name][:misspelling] == '1')
      @name.misspelling = true
      @name_primer = Name.primer
    end

    # Only allowed to make substantive changes if you own all the references
    # to it.  I think checking that the user owns all the namings that use it
    # is correct.  Maybe we should also check observations?  But the
    # observation simply caches the winning naming's name.  Actually not
    # necessarily: obs might use the accepted name if the winning name is
    # deprecated.  Hmmm, I'll check it to be safe.
    @can_make_changes = true
    if !is_in_admin_mode?
      for obj in @name.namings + @name.observations
        if obj.user_id != @user.id
          @can_make_changes = false
          break
        end
      end
    end

    if request.method == :post
      any_errors = false
      begin
        # Look up name to see if it already exists.
        text_name = params[:name][:text_name].to_s.strip_squeeze
        author    = params[:name][:author].to_s.strip_squeeze
        rank      = params[:name][:rank].to_s
        name_str  = text_name
        matches   = nil
        if author != ''
          matches = Name.find_all_by_text_name_and_author(text_name, author)
          name_str += " #{author}"
        else
          matches = Name.find_all_by_text_name(text_name)
        end

        # Take first one that isn't us if there are several matches.  This is
        # the name that we will merge this name into.
        merge = nil
        for match in matches || []
          if match.id != @name.id
            merge = match
            break
          end
        end

        # Merge this name into another.
        if merge
          # Copy over any info this name has that the other name doesn't.
          # Use other name's info where there's conflict.  (Reason: this is
          # most often used to *get rid* of a misspelt name, such names are
          # frequently accidentally created, often with incorrect rank.)
          if merge_name.author.to_s == ''
            merge.author = author
          end
          if merge_name.citation.to_s == ''
            merge.citation = params[:name][:citation].to_s.strip_squeeze
          end
          merge.change_text_name(merge.text_name, merge.author, merge.rank,
                                 :save_parents)

          # Admins can actually merge them, then redirect to other location.
          if is_in_admin_mode?
            merge.merge(@name)
            save_name(merge, :log_name_updated) if merge.changed?
            flash_notice(:runtime_edit_name_merge_success.t(
              :this => @name.search_name, :that => merge.search_name))
            @name = merge

          # Non-admins just send email-request to admins.
          else
            flash_warning(:merge_names_warning.t)
            content = :email_name_merge.t(:user => @user.login,
                      :this => @name.display_name, :that => merge.display_name)
            AccountMailer.deliver_webmaster_question(@user.email, content)
          end

        # Not merging.
        else
          @name.change_text_name(text_name, author, rank, :save_parents)
          @name.citation = params[:name][:citation].to_s.strip_squeeze rescue ''

          # Let user call this name a misspelling.
          @misspelling = (params[:name][:misspelling] == '1') rescue false
          @correct_spelling = params[:name][:correct_spelling].to_s.strip_squeeze rescue ''
          if !update_correct_spelling(@name, @misspelling, @correct_spelling)
            # In case of error, save the rest of the changes, but stay in form.
            any_errors = true
          end

          # Save any changes.
          if !@name.changed?
            flash_warning(:runtime_edit_name_no_change.t)
          elsif !save_name(@name, :log_name_updated)
            raise(:runtime_unable_to_save_changes.t)
          else
            flash_notice(:runtime_edit_name_success.t(
                         :name => @name.search_name))
          end
        end

      rescue RuntimeError => err
        # Anything causing changes not to get saved ends up here.
        flash_error(err.to_s) if !err.nil?
        flash_object_errors(@name)
        @name.attributes = params[:name]

      else
        if !any_errors
          # If no errors occurred, assume changes were made successfully.
          redirect_to(:action => 'show_name', :id => @name.id,
                      :params => query_params)
        end
      end
    end
  end

  def create_name_description
    store_location
    pass_query_params
    @name = Name.find(params[:id])
    @licenses = License.current_names_and_ids

    # Reder a blank form.
    if request.method == :get
      @description = NameDescription.new
      @description.name = @name
      @description.license = @user.license

      # Initialize source-specific stuff.
      case params[:source]
      when 'project'
        @description.source_type  = :project
        @description.source_name  = Project.find(params[:project])
        @description.public       = false
        @description.public_write = false
      else
        @description.source_type  = :public
        @description.public       = true
        @description.public_write = true
      end

    # Create new description.
    else
      @description = NameDescription.new
      @description.name = @name
      @description.attributes = params[:description]

      if @description.save
        initialize_description_permissions(@description)

        Transaction.post_name_description(
          @description.all_notes.merge(
            :id            => @description,
            :created       => @description.created,
            :source_type   => @description.source_type,
            :source_name   => @description.source_name,
            :locale        => @description.locale,
            :license       => @description.license,
            :admin_groups  => @description.admin_groups,
            :writer_groups => @description.writer_groups,
            :reader_groups => @description.reader_groups
          )
        )

        # Make this the "default" description if there isn't one and this is
        # publically readable.
        if !@name.description and
           @description.public
          @name.description = @description
        end

        # Keep the parent's classification cache up to date.
        if (@name.description == @description) and
           (@name.classification != @description.classification)
          @name.classification = @description.classification
        end

        # Save any changes to parent name.
        @name.save if @name.changed?

        flash_notice(:runtime_name_description_success.t(
                     :id => @description.id))
        redirect_to(:action => 'show_name_description',
                    :id => @description.id)

      else
        flash_object_errors @description
      end
    end
  end

  def edit_name_description
    store_location
    pass_query_params
    @description = NameDescription.find(params[:id])
    @licenses = License.current_names_and_ids

    if request.method == :post
      @description.attributes = params[:description]

      args = {}
      args["set_source_type"] = @description.source_type if @description.source_type_changed?
      args["set_source_name"] = @description.source_name if @description.source_name_changed?
      args["set_locale"]      = @description.locale      if @description.locale_changed?
      args["set_license"]     = @description.license     if @description.license_id_changed?
      for field in NameDescription.all_note_fields
        if @description.send("#{field}_changed?")
          args["set_#{field}".to_sym] = @description.send(field)
        end
      end

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description, args)

      # If substantive changes are made by a reviewer, call this act a
      # "review", even though they haven't actually changed the review
      # status.  If it's a non-reviewer, this will revert it to "unreviewed". 
      if @description.save_version?
        @description.update_review_status(@description.review_status, @user,
                                          Time.now)
      end

      # No changes made.
      if args.empty?
        flash_warning(:runtime_edit_name_description_no_change.t)
        redirect_to(:action => 'show_name_description',
                    :id => @description.id)

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        if !args.empty?
          args[:id] = @description
          Transaction.put_name_description(args)
        end

        # Update name's classification cache.
        name = @description.name
        if (name.description == @description) and
           (name.classification != @description.classification)
          name.classification = @description.classification
          name.save
        end

        flash_notice(:runtime_edit_name_description_success.t(
                     :id => @description.id))
        redirect_to(:action => 'show_name_description',
                    :id => @description.id)
      end
    end
  end

  def destroy_name_description
    pass_query_params
    @description = NameDescription.find(params[:id])
    if !@description.is_admin?(@user)
      flash_error(:runtime_destroy_description_not_admin.t)
      redirect_to(:action => 'show_name_description', :id => @description.id,
                  :params => query_params)
    else
      flash_notice(:runtime_destroy_description_success.t)
      @description.destroy
      redirect_to(:action => 'show_name', :id => @description.name_id,
                  :params => query_params)
    end
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
          flash_error(:runtime_form_names_misspelling_bad.t)
        elsif result.id == self.id
          flash_error(:runtime_form_names_misspelling_same.t)
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
          save_name(name2, :log_name_unmisspelled, :other => name.display_name)
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

        # Create synonym and add this name to it if this name not already
        # associated with a synonym.
        if !@name.synonym_id
          @name.synonym = Synonym.create
          @name.save
          Transaction.post_synonym(
            :id => @name.synonym
          )
          Transaction.put_name(
            :id          => @name,
            :set_synonym => @name.synonym
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
            if n.synonym_id != @name.synonym_id
              @name.transfer_synonym(n)
              Transaction.put_name(
                :id          => n,
                :set_synonym => @name.synonym
              )
            end
          end
        end

        # De-synonymize any old synonyms in the "existing synonyms" list that
        # have been unchecked.  This creates a new synonym to connect them if
        # there are multiple unchecked names -- that is, it splits this
        # synonym into two synonyms, with checked names staying in this one,
        # and unchecked names moving to the new one.
        check_for_new_synonym(@name, @name.synonyms, params[:existing_synonyms] || {})

        # Deprecate everything if that check-box has been marked.
        success = true
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
    @what    = params[:proposed][:name].to_s.strip_squeeze rescue ''
    @comment = params[:comment][:comment].to_s.strip_squeeze rescue ''

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
        flash_error :runtime_name_deprecate_must_choose.t

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
          tag = :log_name_approved
          args = { :other => @name.search_name }
          if @comment != ''
            tag = :log_name_approved_with_comment
            args[:comment] = @comment
          end
          save_name(target_name, tag, args)

          # Change this name to "deprecated", set correct spelling, add note.
          @name.change_deprecated(true)
          if @misspelling
            @name.misspelling = true
            @name.correct_spelling = target_name
          end
          comment_join = @comment == "" ? "." : ":\n"
          tag = :log_name_deprecated
          args = { :other => target_name.search_name }
          if @comment != ''
            tag = :log_name_deprecated_with_comment
            args[:comment] = @comment
          end
          save_name(@name, tag, args)

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
    comment = params[:comment][:comment] rescue ''
    comment = comment.strip_squeeze
    if request.method == :post

      # Deprecate others first.
      others = []
      if params[:deprecate][:others] == '1'
        for n in @name.approved_synonyms
          n.change_deprecated(true)
          tag = :log_name_deprecated
          args = { :other => @name.search_name }
          if comment == ''
            tag = :log_name_deprecated_with_comment
            args[:comment] = comment
          end
          save_name(n, tag, args)
          others << n.search_name
        end
      end

      # Approve this now.
      @name.change_deprecated(false)
      tag = :log_approved_by
      args = {}
      if others != []
        tag = :log_name_approved
        args[:other] = others.join(', ')
      end
      if comment == ''
        tag = "#{tag}_with_comment".to_sym
        args[:comment] = comment
      end
      save_name(@name, tag, args)

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
        result = save_name(name, :log_deprecated_by)
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
      name = new_synonym_members.shift
      name.synonym = new_synonym = Synonym.create
      name.save
      Transaction.post_synonym(
        :id => new_synonym
      )
      Transaction.put_name(
        :id          => name,
        :set_synonym => new_synonym
      )
      for n in new_synonym_members
        name.transfer_synonym(n)
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
      sorter = NameSorter.new
      sorter.add_chosen_names(params[:chosen_multiple_names]) # hash on id
      sorter.add_chosen_names(params[:chosen_approved_names]) # hash on id
      sorter.add_approved_deprecated_names(params[:approved_deprecated_names])
      sorter.check_for_deprecated_checklist(params[:checklist_data])
      sorter.sort_names(list)
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
      when :ENABLE.l, :UPDATE.l
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
      when :DISABLE.l
        @notification.destroy
        flash_notice(:email_tracking_no_longer_tracking.t(:name => name.display_name))
      end
      redirect_to(:action => 'show_name', :id => name_id, :params => query_params)
    end
  end
end
