#
#  = Name Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  index_name::                  List of results of index/search.
#  list_names::                  Alphabetical list of all names, used or otherwise.
#  observation_index::           Alphabetical list of names people have seen.
#  names_by_user::               Alphabetical list of names created by given user.
#  names_by_editor::             Alphabetical list of names edited by given user.
#  name_search::                 Seach for string in name, notes, etc.
#  map::                         Show distribution map.
#  index_name_description::      List of results of index/search.
#  list_name_descriptions::      Alphabetical list of all name_descriptions,
#                                used or otherwise.
#  name_descriptions_by_author:: Alphabetical list of name_descriptions authored
#                                by given user.
#  name_descriptions_by_editor:: Alphabetical list of name_descriptions edited
#                                by given user.
#  show_name::                   Show info about name.
#  show_past_name::              Show past versions of name info.
#  prev_name::                   Show previous name in index.
#  next_name::                   Show next name in index.
#  show_name_description::       Show info about name_description.
#  show_past_name_description::  Show past versions of name_description info.
#  prev_name_description::       Show previous name_description in index.
#  next_name_description::       Show next name_description in index.
#  create_name::                 Create new name.
#  edit_name::                   Edit name.
#  create_name_description::     Create new name_description.
#  edit_name_description::       Edit name_description.
#  destroy_name_description::    Destroy name_description.
#  make_description_default::    Make a description the default one.
#  merge_descriptions::          Merge a description with another.
#  publish_description::         Publish a draft description.
#  adjust_permissions::          Adjust permissions on a description.
#  change_synonyms::             Change list of synonyms for a name.
#  deprecate_name::              Deprecate name in favor of another.
#  approve_name::                Flag given name as "accepted"
#                                (others could be, too).
#  bulk_name_edit::              Create/synonymize/deprecate a list of names.
#  names_for_mushroom_app::      Display list of most common names in plain text.
#  edit_lifeform::               Edit lifeform tags.
#  propagate_lifeform::          Add/remove lifeform tags to/from subtaxa.
#  propagate_classification::    Copy classification to all subtaxa.
#  refresh_classification::      Refresh classification from genus.
#
#  ==== Helpers
#  deprecate_synonym::           (used by change_synonyms)
#  check_for_new_synonym::       (used by change_synonyms)
#  dump_sorter::                 Error diagnostics for change_synonyms.
#
class NameController < ApplicationController
  require_dependency "name_controller/create_and_edit_name"
  require_dependency "name_controller/classification"
  require_dependency "name_controller/show_name_description"

  include DescriptionControllerHelpers

  before_action :login_required, except: [
    :advanced_search,
    :authored_names,
    :eol,
    :eol_preview,
    :index_name,
    :index_name_description,
    :map,
    :list_name_descriptions,
    :list_names,
    :name_search,
    :name_descriptions_by_author,
    :name_descriptions_by_editor,
    :names_by_user,
    :names_by_editor,
    :needed_descriptions,
    :next_name,
    :next_name_description,
    :observation_index,
    :prev_name,
    :prev_name_description,
    :show_name,
    :show_name_description,
    :show_past_name,
    :show_past_name_description,
    :test_index
  ]

  before_action :disable_link_prefetching, except: [
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
    :show_past_name_description
  ]

  ##############################################################################
  #
  #  :section: Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name # :nologin: :norobots:
    query = find_or_create_query(:Name, by: params[:by])
    show_selected_names(query, id: params[:id].to_s, always_index: true)
  end

  # Display list of all (correctly-spelled) names in the database.
  def list_names # :nologin:
    query = create_query(:Name, :all, by: :name)
    show_selected_names(query)
  end

  # Display list of names that have observations.
  def observation_index # :nologin: :norobots:
    query = create_query(:Name, :with_observations)
    show_selected_names(query)
  end

  # Display list of names that have authors.
  def authored_names # :nologin: :norobots:
    query = create_query(:Name, :with_descriptions)
    show_selected_names(query)
  end

  # Display list of names that a given user is author on.
  def names_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      query = create_query(:Name, :by_user, user: user)
      show_selected_names(query)
    end
  end

  # This no longer makes sense, but is being requested by robots.
  alias_method :names_by_author, :names_by_user

  # Display list of names that a given user is editor on.
  def names_by_editor # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      query = create_query(:Name, :by_editor, user: user)
      show_selected_names(query)
    end
  end

  # Display list of the most popular 100 names that don't have descriptions.
  def needed_descriptions # :nologin: :norobots:
    # NOTE!! -- all this extra info and help will be lost if user re-sorts.
    data = Name.connection.select_rows %(
      SELECT names.id, name_counts.count
      FROM names LEFT OUTER JOIN name_descriptions ON names.id = name_descriptions.name_id,
           (SELECT count(*) AS count, name_id
            FROM observations group by name_id) AS name_counts
      WHERE names.id = name_counts.name_id
        AND names.rank = #{Name.ranks[:Species]}
        AND name_counts.count > 1
        AND name_descriptions.name_id IS NULL
        AND CURRENT_TIMESTAMP - names.updated_at > #{1.week.to_i}
      ORDER BY name_counts.count DESC, names.sort_name ASC
      LIMIT 100
    )
    @help = :needed_descriptions_help
    query = create_query(:Name, :in_set,
                         ids: data.map(&:first),
                         title: :needed_descriptions_title.l)
    show_selected_names(query, num_per_page: 100)
  end

  # Display list of names that match a string.
  def name_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (name = Name.safe_find(pattern))
      redirect_to(action: "show_name", id: name.id)
    else
      search = PatternSearch::Name.new(pattern)
      if search.errors.any?
        search.errors.each do |error|
          flash_error(error.to_s)
        end
        render(action: :list_names)
      else
        @suggest_alternate_spellings = search.query.params[:pattern]
        show_selected_names(search.query)
      end
    end
  end

  # Displays list of advanced search results.
  def advanced_search # :nologin: :norobots:
    query = find_query(:Name)
    show_selected_names(query)
  rescue => err
    flash_error(err.to_s) unless err.blank?
    redirect_to(controller: "observer", action: "advanced_search_form")
  end

  # Used to test pagination.
  def test_index # :nologin: :norobots:
    query = find_query(:Name) or raise("Missing query: #{params[:q]}")
    if params[:test_anchor]
      @test_pagination_args = { anchor: params[:test_anchor] }
    end
    show_selected_names(query, num_per_page: params[:num_per_page].to_i)
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_names(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "list_names",
      letters: "names.sort_name",
      num_per_page: (params[:letter].to_s.match(/^[a-z]/i) ? 500 : 50)
    }.merge(args)

    # Tired of not having an easy link to list_names.
    if query.flavor == :with_observations
      @links << [:all_objects.t(type: :name), { action: "list_names" }]
    end

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_name.t],
      ["created_at",  :sort_by_created_at.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t],
      ["num_views", :sort_by_num_views.t]
    ]

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Observation)

    # Add "show descriptions" link if this query can be coerced into a
    # description query.
    if query.coercable?(:NameDescription)
      @links << [:show_objects.t(type: :description),
                 add_query_param({ action: "index_name_description" },
                                 query)]
    end

    # Add some extra fields to the index for authored_names.
    if query.flavor == :with_descriptions
      show_index_of_objects(query, args) do |name|
        if desc = name.description
          [desc.authors.map(&:login).join(", "),
           desc.note_status.map(&:to_s).join("/"),
           :"review_#{desc.review_status}".t]
        else
          []
        end
      end
    else
      # Note: if show_selected_name is called with a block
      # it will *not* get passed to show_index_of_objects.
      show_index_of_objects(query, args)
    end
  end

  ##############################################################################
  #
  #  :section: Description Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name_description # :nologin: :norobots:
    query = find_or_create_query(:NameDescription, by: params[:by])
    show_selected_name_descriptions(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Display list of all (correctly-spelled) name_descriptions in the database.
  def list_name_descriptions # :nologin:
    query = create_query(:NameDescription, :all, by: :name)
    show_selected_name_descriptions(query)
  end

  # Display list of name_descriptions that a given user is author on.
  def name_descriptions_by_author # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      query = create_query(:NameDescription, :by_author, user: user)
      show_selected_name_descriptions(query)
    end
  end

  # Display list of name_descriptions that a given user is editor on.
  def name_descriptions_by_editor # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      query = create_query(:NameDescription, :by_editor, user: user)
      show_selected_name_descriptions(query)
    end
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_name_descriptions(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "list_name_descriptions",
      num_per_page: 50
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_name.t],
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["num_views",   :sort_by_num_views.t]
    ]

    # Add "show names" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Name)

    show_index_of_objects(query, args)
  end

  ################################################################################
  #
  #  :section: Show Name
  #
  ################################################################################

  # Show a Name, one of its NameDescription's, associated taxa, and a bunch of
  # relevant Observations.
  def show_name # :nologin: :prefetch:
    pass_query_params
    store_location
    clear_query_in_session

    # Load Name and NameDescription along with a bunch of associated objects.
    name_id = params[:id].to_s
    desc_id = params[:desc]
    if @name = find_or_goto_index(Name, name_id)
      @canonical_url = "#{MO.http_domain}/name/show_name/#{@name.id}"

      update_view_stats(@name)

      # Tell robots the proper URL to use to index this content.
      @canonical_url = "#{MO.http_domain}/name/show_name/#{@name.id}"

      # Get a list of projects the user can create drafts for.
      @projects = @user && @user.projects_member.select do |project|
        !@name.descriptions.any? { |d| d.belongs_to_project?(project) }
      end

      # Create query for immediate children.
      @children_query = create_query(:Name, :of_children, name: @name)
      if @name.at_or_below_genus?
        args = { name: @name, all: true, by: :confidence }
        @subtaxa_query = create_query(:Observation, :of_children, args)
      end

      # Create search queries for observation lists.
      args = { name: @name, by: :confidence }
      @consensus_query = create_query(:Observation, :of_name, args)

      args = { name: @name, by: :confidence, has_images: :yes }
      @obs_with_images_query = create_query(:Observation, :of_name, args)

      # Determine which queries actually have results and instantiate the ones
      # we'll use.
      @best_description = @name.best_brief_description
      @first_four       = @obs_with_images_query.results(limit: 4)
      @first_child      = @children_query.results(limit: 1).first
      @first_consensus  = @consensus_query.results(limit: 1).first
      @has_subtaxa      = @subtaxa_query.select_count if @subtaxa_query
    end
  end

  # Show past version of Name.  Accessible only from show_name page.
  def show_past_name # :nologin: :prefetch: :norobots:
    pass_query_params
    store_location
    if @name = find_or_goto_index(Name, params[:id].to_s)
      @name.revert_to(params[:version].to_i)

      # Old correct spellings could have gotten merged with something else and no longer exist.
      if @name.is_misspelling?
        @correct_spelling = Name.connection.select_value %(
          SELECT display_name FROM names WHERE id = #{@name.correct_spelling_id}
        )
      else
        @correct_spelling = ""
      end
    end
  end

  # Show past version of NameDescription.  Accessible only from
  # show_name_description page.
  def show_past_name_description # :nologin: :prefetch: :norobots:
    pass_query_params
    store_location
    if @description = find_or_goto_index(NameDescription, params[:id].to_s)
      @name = @description.name
      if params[:merge_source_id].blank?
        @description.revert_to(params[:version].to_i)
      else
        @merge_source_id = params[:merge_source_id]
        version = NameDescription::Version.find(@merge_source_id)
        @old_parent_id = version.name_description_id
        subversion = params[:version]
        if !subversion.blank? &&
           (version.version != subversion.to_i)
          version = NameDescription::Version.
                    find_by_version_and_name_description_id(params[:version], @old_parent_id)
        end
        @description.clone_versioned_model(version, @description)
      end
    end
  end

  # Go to next name: redirects to show_name.
  def next_name # :nologin: :norobots:
    redirect_to_next_object(:next, Name, params[:id].to_s)
  end

  # Go to previous name: redirects to show_name.
  def prev_name # :nologin: :norobots:
    redirect_to_next_object(:prev, Name, params[:id].to_s)
  end

  # Go to next name: redirects to show_name.
  def next_name_description # :nologin: :norobots:
    redirect_to_next_object(:next, NameDescription, params[:id].to_s)
  end

  # Go to previous name_description: redirects to show_name_description.
  def prev_name_description # :nologin: :norobots:
    redirect_to_next_object(:prev, NameDescription, params[:id].to_s)
  end

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status # :norobots:
    pass_query_params
    id = params[:id].to_s
    desc = NameDescription.find(id)
    desc.update_review_status(params[:value]) if reviewer?
    redirect_with_query(action: :show_name, id: desc.name_id)
  end

  ##############################################################################
  #
  #  :section: Create and Edit Name Descriptions
  #
  ##############################################################################

  def create_name_description # :prefetch: :norobots:
    store_location
    pass_query_params
    @name = Name.find(params[:id].to_s)
    @licenses = License.current_names_and_ids

    # Render a blank form.
    if request.method == "GET"
      @description = NameDescription.new
      @description.name = @name
      initialize_description_source(@description)

    # Create new description.
    else
      @description = NameDescription.new
      @description.name = @name
      @description.attributes = whitelisted_name_description_params
      @description.source_type = @description.source_type.to_sym

      if @description.valid?
        initialize_description_permissions(@description)
        @description.save

        # Make this the "default" description if there isn't one and this is
        # publicly readable and writable.
        if !@name.description &&
           @description.fully_public
          @name.description = @description
        end

        # Keep the parent's classification cache up to date.
        if (@name.description == @description) &&
           (@name.classification != @description.classification)
          @name.classification = @description.classification
        end

        # Log action in parent name.
        @description.name.log(:log_description_created_at,
                              user: @user.login, touch: true,
                              name: @description.unique_partial_format_name)

        # Save any changes to parent name.
        @name.save if @name.changed?

        flash_notice(:runtime_name_description_success.t(
                       id: @description.id
        ))
        redirect_to(action: "show_name_description",
                    id: @description.id)

      else
        flash_object_errors @description
      end
    end
  end

  # :prefetch: :norobots:
  def edit_name_description
    store_location
    pass_query_params
    @description = NameDescription.find(params[:id].to_s)
    @licenses = License.current_names_and_ids

    if !check_description_edit_permission(@description, params[:description])
      # already redirected

    elsif request.method == "POST"
      @description.attributes = whitelisted_name_description_params
      @description.source_type = @description.source_type.to_sym

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description)

      # If substantive changes are made by a reviewer, call this act a
      # "review", even though they haven't actually changed the review
      # status.  If it's a non-reviewer, this will revert it to "unreviewed".
      if @description.save_version?
        @description.update_review_status(@description.review_status)
      end

      # No changes made.
      if !@description.changed?
        flash_warning(:runtime_edit_name_description_no_change.t)
        redirect_to(action: "show_name_description", id: @description.id)

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        flash_notice(:runtime_edit_name_description_success.t(
                       id: @description.id
        ))

        # Update name's classification cache.
        name = @description.name
        if (name.description == @description) &&
           (name.classification != @description.classification)
          name.classification = @description.classification
          name.save
        end

        # Log action to parent name.
        name.log(:log_description_updated, touch: true, user: @user.login,
                                           name: @description.unique_partial_format_name)

        # Delete old description after resolving conflicts of merge.
        if (params[:delete_after] == "true") &&
           (old_desc = NameDescription.safe_find(params[:old_desc_id]))
          v = @description.versions.latest
          v.merge_source_id = old_desc.versions.latest.id
          v.save
          if !in_admin_mode? && !old_desc.is_admin?(@user)
            flash_warning(:runtime_description_merge_delete_denied.t)
          else
            flash_notice(:runtime_description_merge_deleted.
                           t(old: old_desc.partial_format_name))
            name.log(:log_object_merged_by_user,
                     user: @user.login, touch: true,
                     from: old_desc.unique_partial_format_name,
                     to: @description.unique_partial_format_name)
            old_desc.destroy
          end
        end

        redirect_to(action: "show_name_description",
                    id: @description.id)
      end
    end
  end

  def destroy_name_description # :norobots:
    pass_query_params
    @description = NameDescription.find(params[:id].to_s)
    if in_admin_mode? || @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.name.log(:log_description_destroyed,
                            user: @user.login, touch: true,
                            name: @description.unique_partial_format_name)
      @description.destroy
      redirect_with_query(action: "show_name", id: @description.name_id)
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if in_admin_mode? || @description.is_reader?(@user)
        redirect_with_query(action: "show_name_description",
                            id: @description.id)
      else
        redirect_with_query(action: "show_name", id: @description.name_id)
      end
    end
  end

  private

  # TODO: should public, public_write and source_type be removed from this list?
  # They should be individually checked and set, since we
  # don't want them to have arbitrary values
  def whitelisted_name_description_params
    params.required(:description).
      permit(:classification, :gen_desc, :diag_desc, :distribution, :habitat,
             :look_alikes, :uses, :refs, :notes, :source_name, :project_id,
             :source_type, :public, :public_write)
  end

  public

  ################################################################################
  #
  #  :section: Synonymy
  #
  ################################################################################

  # Form accessible from show_name that lets a user review all the synonyms
  # of a name, removing others, writing in new, etc.
  def change_synonyms # :prefetch: :norobots:
    pass_query_params
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name
    return if abort_if_name_locked!(@name)

    @list_members     = nil
    @new_names        = nil
    @synonym_name_ids = []
    @synonym_names    = []
    @deprecate_all    = true

    post_change_synonyms if request.method == "POST"
  end

  def post_change_synonyms
    list = params[:synonym][:members].strip_squeeze
    @deprecate_all = (params[:deprecate][:all] == "1")

    # Create any new names that have been approved.
    construct_approved_names(list, params[:approved_names], @deprecate_all)

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
      unless @name.synonym_id
        @name.synonym = Synonym.create
        @name.save
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
        if proposed_synonyms[n.id.to_s] != "0"
          @name.transfer_synonym(n) if n.synonym_id != @name.synonym_id
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
      if @deprecate_all
        for n in sorter.all_names
          unless deprecate_synonym(n)
            # Already flashed error message.
            success = false
          end
        end
      end

      if success
        redirect_with_query(action: "show_name", id: @name.id)
      else
        flash_object_errors(@name)
        flash_object_errors(@name.synonym)
      end
    end

    @list_members     = sorter.all_line_strs.join("\r\n")
    @new_names        = sorter.new_name_strs.uniq
    @synonym_name_ids = sorter.all_synonyms.map(&:id)
    @synonym_names    = @synonym_name_ids.map { |id| Name.safe_find(id) }.reject(&:nil?)
  end

  # Form accessible from show_name that lets the user deprecate a name in favor
  # of another name.
  def deprecate_name # :prefetch: :norobots:
    pass_query_params

    # These parameters aren't always provided.
    params[:proposed]    ||= {}
    params[:comment]     ||= {}
    params[:chosen_name] ||= {}
    params[:is]          ||= {}

    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name
    return if abort_if_name_locked!(@name)

    @what             = params[:proposed][:name].to_s.strip_squeeze
    @comment          = params[:comment][:comment].to_s.strip_squeeze
    @list_members     = nil
    @new_names        = []
    @synonym_name_ids = []
    @synonym_names    = []
    @deprecate_all    = "1"
    @names            = []
    @misspelling      = (params[:is][:misspelling] == "1")

    post_deprecate_name if request.method == "POST"
  end

  def post_deprecate_name
    if @what.blank?
      flash_error :runtime_name_deprecate_must_choose.t
      return
    end

    # Find the chosen preferred name.
    if params[:chosen_name][:name_id] &&
       name = Name.safe_find(params[:chosen_name][:name_id])
      @names = [name]
    else
      @names = Name.find_names_filling_in_authors(@what)
    end
    approved_name = params[:approved_name].to_s.strip_squeeze
    if @names.empty? &&
       (new_name = Name.create_needed_names(approved_name, @what))
      @names = [new_name]
    end
    target_name = @names.first

    # No matches: try to guess.
    if @names.empty?
      @valid_names = Name.suggest_alternate_spellings(@what)
      @suggest_corrections = true

    # If written-in name matches uniquely an existing name:
    elsif target_name && @names.length == 1
      now = Time.now

      # Merge this name's synonyms with the preferred name's synonyms.
      @name.merge_synonyms(target_name)

      # Change target name to "undeprecated".
      target_name.change_deprecated(false)
      target_name.save_with_log(:log_name_approved, other: @name.real_search_name)

      # Change this name to "deprecated", set correct spelling, add note.
      @name.change_deprecated(true)
      @name.mark_misspelled(target_name) if @misspelling
      @name.save_with_log(:log_name_deprecated, other: target_name.real_search_name)
      post_comment(:deprecate, @name, @comment) unless @comment.blank?

      redirect_with_query(action: "show_name", id: @name.id)
    end
  end

  # Form accessible from show_name that lets a user make call this an accepted
  # name, possibly deprecating its synonyms at the same time.
  def approve_name # :prefetch: :norobots:
    pass_query_params
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name
    return if abort_if_name_locked!(@name)
    @approved_names = @name.approved_synonyms
    return unless request.method == "POST"
    deprecate_others
    approve_this_one
    post_approval_comment
    redirect_with_query(@name.show_link_args)
  end

  def abort_if_name_locked!(name)
    return false if !name.locked || in_admin_mode?
    flash_error(:permission_denied.t)
    redirect_back_or_default("/")
  end

  def deprecate_others
    return unless params[:deprecate] && params[:deprecate][:others] == "1"
    @others = []
    @name.approved_synonyms.each do |n|
      n.change_deprecated(true)
      n.save_with_log(:log_name_deprecated, other: @name.real_search_name)
      @others << n.real_search_name
    end
  end

  def approve_this_one
    @name.change_deprecated(false)
    tag = :log_approved_by
    args = {}
    if @others.any?
      tag = :log_name_approved
      args[:other] = @others.join(", ")
    end
    @name.save_with_log(tag, args)
  end

  def post_approval_comment
    return unless params[:comment]
    comment = params[:comment][:comment]
    return unless comment.present?
    post_comment(:approve, @name, comment.strip_squeeze)
  end

  # Helper used by change_synonyms.  Deprecates a single name.  Returns true
  # if it worked.  Flashes an error and returns false if it fails for whatever
  # reason.
  def deprecate_synonym(name)
    return true if name.deprecated
    begin
      name.change_deprecated(true)
      name.save_with_log(:log_deprecated_by)
    rescue RuntimeError => err
      flash_error(err.to_s) unless err.blank?
      false
    end
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
      new_synonym_members.push(n) if (name != n) && (checks[n.id.to_s] == "0")
    end
    len = new_synonym_members.length
    if len > 1
      name = new_synonym_members.shift
      name.synonym = new_synonym = Synonym.create
      name.save
      for n in new_synonym_members
        name.transfer_synonym(n)
      end
    elsif len == 1
      name = new_synonym_members.first
      name.clear_synonym
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

  # Post a comment after approval or deprecation if the user entered one.
  def post_comment(action, name, message)
    summary = :"name_#{action}_comment_summary".l
    comment = Comment.create!(
      target: name,
      summary: summary,
      comment: message
    )
  end

  ############################################################################
  #
  #  :section: EOL Feed
  #
  ############################################################################

  # Show the data getting sent to EOL
  def eol_preview # :nologin: :norobots:
    @timer_start = Time.now
    eol_data(NameDescription.review_statuses.values_at(:unvetted, :vetted))
    @timer_end = Time.now
  end

  def eol_description_conditions(review_status_list)
    # name descriptions that are exportable.
    rsl = review_status_list.join("', '")
    "review_status IN ('#{rsl}') AND " \
                 "gen_desc IS NOT NULL AND " \
                 "ok_for_export = 1 AND " \
                 "public = 1"
  end

  # Gather data for EOL feed.
  def eol_data(review_status_list)
    @names      = []
    @descs      = {} # name.id    -> [NameDescription, NmeDescription, ...]
    @image_data = {} # name.id    -> [img.id, obs.id, user.id, lic.id, date]
    @users      = {} # user.id    -> user.legal_name
    @licenses   = {} # license.id -> license.url
    @authors    = {} # desc.id    -> "user.legal_name, user.legal_name, ..."

    descs = NameDescription.where(
      eol_description_conditions(review_status_list)
    )

    # Fill in @descs, @users, @authors, @licenses.
    descs.each do |desc|
      name_id = desc.name_id.to_i
      @descs[name_id] ||= []
      @descs[name_id] << desc
      authors = Name.connection.select_values(%(
        SELECT user_id FROM name_descriptions_authors
        WHERE name_description_id = #{desc.id}
      )).map(&:to_i)
      authors = [desc.user_id] if authors.empty?
      authors.each do |author|
        @users[author.to_i] ||= User.find(author).legal_name
      end
      @authors[desc.id] = authors.map { |id| @users[id.to_i] }.join(", ")
      @licenses[desc.license_id] ||= desc.license.url if desc.license_id
    end

    # Get corresponding names.
    name_ids = @descs.keys.map(&:to_s).join(",")
    @names = Name.where(id: name_ids).order(:sort_name, :author).to_a

    # Get corresponding images.
    image_data = Name.connection.select_all %(
      SELECT name_id, image_id, observation_id, images.user_id,
             images.license_id, images.created_at
      FROM observations, images_observations, images
      WHERE observations.name_id IN (#{name_ids})
      AND observations.vote_cache >= 2.4
      AND observations.id = images_observations.observation_id
      AND images_observations.image_id = images.id
      AND images.vote_cache >= 2
      AND images.ok_for_export
      ORDER BY observations.vote_cache
    )
    image_data = image_data.to_a

    # Fill in @image_data, @users, and @licenses.
    for row in image_data
      name_id    = row["name_id"].to_i
      user_id    = row["user_id"].to_i
      license_id = row["license_id"].to_i
      image_datum = row.values_at("image_id", "observation_id", "user_id",
                                  "license_id", "created_at")
      @image_data[name_id] ||= []
      @image_data[name_id].push(image_datum)
      @users[user_id] ||= User.find(user_id).legal_name
      @licenses[license_id] ||= License.find(license_id).url
    end
  end

  def eol_expanded_review
    @timer_start = Time.now
    @data = EolData.new
  end
  # TODO: Add ability to preview synonyms?
  # TODO: List stuff that's almost ready.
  # TODO: Add EOL logo on pages getting exported
  #   show_name and show_descriptions for description info
  #   show_name, show_observation and show_image for images
  # EOL preview from Name page
  # Improve the Name page
  # Review unapproved descriptions

  # Send stuff to eol.
  def eol # :nologin: :norobots:
    @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
    @timer_start = Time.now
    @data = EolData.new
    render_xml(layout: false)
  end

  ################################################################################
  #
  #  :section: Other Stuff
  #
  ################################################################################

  # Utility accessible from a number of name pages (e.g. indexes and
  # show_name?) that lets you enter a whole list of names, together with
  # synonymy, and create them all in one blow.
  def bulk_name_edit # :prefetch: :norobots:
    @list_members = nil
    @new_names    = nil
    if request.method == "POST"
      list = begin
               params[:list][:members].strip_squeeze
             rescue
               ""
             end
      construct_approved_names(list, params[:approved_names])
      sorter = NameSorter.new
      sorter.sort_names(list)
      if sorter.only_single_names
        sorter.create_new_synonyms
        flash_notice :name_bulk_success.t
        redirect_to(controller: "observer", action: "list_rss_logs")
      else
        if sorter.new_name_strs != []
          # This error message is no longer necessary.
          flash_error "Unrecognized names given, including: #{sorter.new_name_strs[0].inspect}" if Rails.env == "test"
        else
          # Same with this one... err, no this is not reported anywhere.
          flash_error "Ambiguous names given, including: #{sorter.multiple_line_strs[0].inspect}"
        end
        @list_members = sorter.all_line_strs.join("\r\n")
        @new_names    = sorter.new_name_strs.uniq.sort
      end
    end
  end

  # Draw a map of all the locations where this name has been observed.
  def map # :nologin: :norobots:
    pass_query_params
    if @name = find_or_goto_index(Name, params[:id].to_s)
      @query = create_query(:Observation, :of_name, name: @name)
      apply_content_filters(@query)
      @observations = @query.results.select { |o| o.lat || o.location }
    end
  end

  # Form accessible from show_name that lets a user setup tracker notifications
  # for a name.
  def email_tracking # :norobots:
    pass_query_params
    name_id = params[:id].to_s
    return unless @name = find_or_goto_index(Name, name_id)

    flavor = Notification.flavors[:name]
    @notification = Notification.
                    find_by_flavor_and_obj_id_and_user_id(flavor, name_id,
                                                          @user.id)
    if request.method != "POST"
      initialize_tracking_form
    else
      submit_tracking_form(name_id)
    end
  end

  def initialize_tracking_form
    unless @name.at_or_below_genus?
      flash_warning(:email_tracking_enabled_only_for.t(name: @name.display_name,
                                                       rank: @name.rank))
    end
    if @notification
      @note_template = @notification.note_template
    else
      @note_template = :email_tracking_note_template.l(
        species_name: @name.real_text_name,
        mailing_address: @user.mailing_address_for_tracking_template,
        users_name: @user.legal_name
      )
    end
  end

  def submit_tracking_form(name_id)
    case params[:commit]
    when :ENABLE.l, :UPDATE.l
      note_template = params[:notification][:note_template]
      note_template = nil if note_template.blank?
      if @notification.nil?
        @notification = Notification.new(flavor: :name, user: @user,
                                         obj_id: name_id,
                                         note_template: note_template)
        flash_notice(:email_tracking_now_tracking.t(name: @name.display_name))
      else
        @notification.note_template = note_template
        flash_notice(:email_tracking_updated_messages.t)
      end
      @notification.save
    when :DISABLE.l
      @notification.destroy
      flash_notice(:email_tracking_no_longer_tracking.t(name: @name.display_name))
    end
    redirect_with_query(action: "show_name", id: name_id)
  end

  def edit_lifeform # :norobots:
    pass_query_params
    @name = find_or_goto_index(Name, params[:id])
    return unless request.method == "POST"
    words = Name.all_lifeforms.select do |word|
      params["lifeform_#{word}"] == "1"
    end
    @name.update_attributes(lifeform: " #{words.join(' ')} ")
    redirect_with_query(@name.show_link_args)
  end

  def propagate_lifeform # :norobots:
    pass_query_params
    @name = find_or_goto_index(Name, params[:id])
    return unless request.method == "POST"
    Name.all_lifeforms.each do |word|
      if params["add_#{word}"] == "1"
        @name.propagate_add_lifeform(word)
      elsif params["remove_#{word}"] == "1"
        @name.propagate_remove_lifeform(word)
      end
    end
    redirect_with_query(@name.show_link_args)
  end

  ################################################################################
  #
  #  :section: Stuff for Mushroom App
  #
  ################################################################################

  def names_for_mushroom_app # :nologin: :norobots:
    number_of_names = params[:number_of_names].blank? ? 1000 : params[:number_of_names]
    minimum_confidence = params[:minimum_confidence].blank? ? 1.5 : params[:minimum_confidence]
    minimum_observations = params[:minimum_observations].blank? ? 5 : params[:minimum_observations]
    rank_condition = params[:include_higher_taxa].blank? ?
      "= #{Name.ranks[:Species]}" :
      "NOT IN (#{Name.ranks.values_at(:Subspecies, :Variety, :Form, :Group).join(",")})"

    data = Name.connection.select_rows(%(
      SELECT y.name, y.rank, SUM(y.number)
      FROM (
        SELECT n.text_name AS name,
               n.rank AS rank,
               x.number AS number
        FROM (
          SELECT n.id AS name_id,
                 n.synonym_id AS synonym_id,
                 COUNT(o.id) AS number
          FROM names n, observations o
          WHERE o.name_id = n.id
            AND o.vote_cache >= #{minimum_confidence}
          GROUP BY IF(n.synonym_id IS NULL, n.id, -n.synonym_id)
        ) AS x
        LEFT OUTER JOIN names n ON IF(x.synonym_id IS NULL, n.id = x.name_id, n.synonym_id = x.synonym_id)
        WHERE n.deprecated = FALSE
          AND x.number >= #{minimum_observations}
          AND n.rank #{rank_condition}
        GROUP BY IF(n.synonym_id IS NULL, n.id, -n.synonym_id)
      ) AS y
      GROUP BY y.name
      ORDER BY SUM(y.number) DESC
      LIMIT #{number_of_names}
    ))

    genera = data.map do |name, _rank, _number|
      name.split(" ").first
    end.uniq

    families = {}
    for genus, classification in Name.connection.select_rows(%(
      SELECT text_name, classification FROM names
      WHERE rank = #{Name.ranks[:Genus]}
        AND COALESCE(classification,'') != ''
        AND text_name IN ('#{genera.join("','")}')
    ))
      for rank, name in Name.parse_classification(classification).reverse
        if rank == :Family
          families[genus] = name
          break
        end
      end
    end

    report = CSV.generate(col_sep: "\t") do |csv|
      csv << %w[name rank number_observations family]
      data.each do |name, rank, number|
        genus = name.split(" ").first
        family = families[genus] || ""
        csv << [name, rank, number.round.to_s, family]
      end
    end
    send_data(report,
              type: "text/csv",
              charset: "UTF-8",
              header: "present",
              disposition: "attachment",
              filename: "#{action_name}.csv")

  rescue => e
    render(text: e.to_s, layout: false, status: 500)
  end
end
