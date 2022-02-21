# frozen_string_literal: true

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
#  list_names::                  Alphabetical list of all names, used or not.
#  observation_index::           Alphabetical list of names people have seen.
#  names_by_user::               Alphabetical list of names created by
#                                given user.
#  names_by_editor::             Alphabetical list of names edited by given user
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

  # rubocop:disable Rails/LexicallyScopedActionFilter
  # No idea how to fix this offense.  If I add another
  #    before_action :login_required, except: :show_name_description
  # in name_controller/show_name_description.rb, it ignores it.
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
    :create_name_description,
    :deprecate_name,
    :edit_name_description,
    :show_name,
    :show_name_description,
    :show_past_name,
    :show_past_name_description
  ]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  ##############################################################################
  #
  #  :section: Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name
    query = find_or_create_query(:Name, by: params[:by])
    show_selected_names(query, id: params[:id].to_s, always_index: true)
  end

  # Display list of all (correctly-spelled) names in the database.
  def list_names
    query = create_query(:Name, :all, by: :name)
    show_selected_names(query)
  end

  # Display list of names that have observations.
  def observation_index
    query = create_query(:Name, :with_observations)
    show_selected_names(query)
  end

  # Display list of names that have authors.
  def authored_names
    query = create_query(:Name, :with_descriptions)
    show_selected_names(query)
  end

  # Display list of names that a given user is author on.
  def names_by_user
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Name, :by_user, user: user)
    show_selected_names(query)
  end

  # This no longer makes sense, but is being requested by robots.
  alias names_by_author names_by_user

  # Display list of names that a given user is editor on.
  def names_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Name, :by_editor, user: user)
    show_selected_names(query)
  end

  # Display list of the most popular 100 names that don't have descriptions.
  def needed_descriptions
    # NOTE!! -- all this extra info and help will be lost if user re-sorts.
    data = Name.connection.select_rows(%(
      SELECT names.id, name_counts.count
      FROM names LEFT OUTER JOIN name_descriptions
        ON names.id = name_descriptions.name_id,
           (SELECT count(*) AS count, name_id
            FROM observations group by name_id) AS name_counts
      WHERE names.id = name_counts.name_id
        # include "to_i" to avoid Brakeman "SQL injection" false positive.
        # (Brakeman does not know that Name.ranks[:xxx] is an enum.)
        AND names.`rank` = #{Name.ranks[:Species].to_i}
        AND name_counts.count > 1
        AND name_descriptions.name_id IS NULL
        AND CURRENT_TIMESTAMP - names.updated_at > #{1.week.to_i}
      ORDER BY name_counts.count DESC, names.sort_name ASC
      LIMIT 100
    ))
    @help = :needed_descriptions_help
    query = create_query(:Name, :in_set,
                         ids: data.map(&:first),
                         title: :needed_descriptions_title.l)
    show_selected_names(query, num_per_page: 100)
  end

  # Display list of names that match a string.
  def name_search
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
  def advanced_search
    return if handle_advanced_search_invalid_q_param?

    query = find_query(:Name)
    show_selected_names(query)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(controller: "observer", action: "advanced_search_form")
  end

  # Used to test pagination.
  def test_index
    query = find_query(:Name)
    raise("Missing query: #{params[:q]}") unless query

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
      num_per_page: (/^[a-z]/i.match?(params[:letter].to_s) ? 500 : 50)
    }.merge(args)

    # Tired of not having an easy link to list_names.
    if query.flavor == :with_observations
      @links << [:all_objects.t(type: :name), { action: "list_names" }]
    end

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name", :sort_by_name.t],
      ["created_at", :sort_by_created_at.t],
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
        if (desc = name.description)
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
  def index_name_description
    query = find_or_create_query(:NameDescription, by: params[:by])
    show_selected_name_descriptions(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Display list of all (correctly-spelled) name_descriptions in the database.
  def list_name_descriptions
    query = create_query(:NameDescription, :all, by: :name)
    show_selected_name_descriptions(query)
  end

  # Display list of name_descriptions that a given user is author on.
  def name_descriptions_by_author
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:NameDescription, :by_author, user: user)
    show_selected_name_descriptions(query)
  end

  # Display list of name_descriptions that a given user is editor on.
  def name_descriptions_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:NameDescription, :by_editor, user: user)
    show_selected_name_descriptions(query)
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

  ##############################################################################
  #
  #  :section: Show Name
  #
  ##############################################################################

  # Show a Name, one of its NameDescription's, associated taxa, and a bunch of
  # relevant Observations.
  def show_name
    pass_query_params
    store_location
    clear_query_in_session

    # Load Name and NameDescription along with a bunch of associated objects.
    name_id = params[:id].to_s
    @name = find_or_goto_index(Name, name_id)
    return unless @name

    update_view_stats(@name)

    # Tell robots the proper URL to use to index this content.
    @canonical_url = "#{MO.http_domain}/name/show_name/#{@name.id}"

    # Get a list of projects the user can create drafts for.
    @projects = @user&.projects_member&.select do |project|
      @name.descriptions.none? { |d| d.belongs_to_project?(project) }
    end

    # Create query for immediate children.
    @children_query = create_query(:Name, :all,
                                   names: @name.id,
                                   include_immediate_subtaxa: true,
                                   exclude_original_names: true)
    if @name.at_or_below_genus?
      @subtaxa_query = create_query(:Observation, :all,
                                    names: @name.id,
                                    include_subtaxa: true,
                                    exclude_original_names: true,
                                    by: :confidence)
    end

    # Create search queries for observation lists.
    @consensus_query = create_query(:Observation, :all,
                                    names: @name.id, by: :confidence)

    @obs_with_images_query = create_query(:Observation, :all,
                                          names: @name.id,
                                          has_images: true,
                                          by: :confidence)

    # Determine which queries actually have results and instantiate the ones
    # we'll use.
    @best_description = @name.best_brief_description
    @first_four       = @obs_with_images_query.results(
                          limit: 4,
                          include: {
                            thumb_image: [:image_votes, :license, :user]
                          }
                        )
    @first_child      = @children_query.results(limit: 1).first
    @first_consensus  = @consensus_query.results(limit: 1).first
    @has_subtaxa      = @subtaxa_query.select_count if @subtaxa_query
  end

  # Show past version of Name.  Accessible only from show_name page.
  def show_past_name
    pass_query_params
    store_location
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name

    @name.revert_to(params[:version].to_i)
    @correct_spelling = ""
    return unless @name.is_misspelling?

    # Old correct spellings could have gotten merged with something else
    # and no longer exist.
    @correct_spelling = Name.connection.select_value(%(
      SELECT display_name FROM names WHERE id = #{@name.correct_spelling_id}
    ))
  end

  # Show past version of NameDescription.  Accessible only from
  # show_name_description page.
  def show_past_name_description
    pass_query_params
    store_location
    @description = find_or_goto_index(NameDescription, params[:id].to_s)
    return unless @description

    @name = @description.name
    if params[:merge_source_id].blank?
      @description.revert_to(params[:version].to_i)
    else
      @merge_source_id = params[:merge_source_id]
      version = NameDescription::Version.find(@merge_source_id)
      @old_parent_id = version.name_description_id
      subversion = params[:version]
      if subversion.present? &&
         (version.version != subversion.to_i)
        version = NameDescription::Version.
                  find_by_version_and_name_description_id(params[:version],
                                                          @old_parent_id)
      end
      @description.clone_versioned_model(version, @description)
    end
  end

  # Go to next name: redirects to show_name.
  def next_name
    redirect_to_next_object(:next, Name, params[:id].to_s)
  end

  # Go to previous name: redirects to show_name.
  def prev_name
    redirect_to_next_object(:prev, Name, params[:id].to_s)
  end

  # Go to next name: redirects to show_name.
  def next_name_description
    redirect_to_next_object(:next, NameDescription, params[:id].to_s)
  end

  # Go to previous name_description: redirects to show_name_description.
  def prev_name_description
    redirect_to_next_object(:prev, NameDescription, params[:id].to_s)
  end

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status
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

  def create_name_description
    store_location
    pass_query_params
    @name = Name.find(params[:id].to_s)
    @licenses = License.current_names_and_ids
    @description = NameDescription.new
    @description.name = @name

    # Render a blank form.
    if request.method == "GET"
      initialize_description_source(@description)

    # Create new description.
    else
      @description.attributes = whitelisted_name_description_params
      @description.source_type = @description.source_type.to_sym

      if @description.valid?
        initialize_description_permissions(@description)
        @description.save

        # Make this the "default" description if there isn't one and this is
        # publicly readable and writable.
        if !@name.description && @description.fully_public
          @name.description = @description
        end

        # Keep the parent's classification cache up to date.
        if (@name.description == @description) &&
           (@name.classification != @description.classification)
          @name.classification = @description.classification
        end

        # Log action in parent name.
        @description.name.log(:log_description_created,
                              user: @user.login,
                              touch: true,
                              name: @description.unique_partial_format_name)

        # Save any changes to parent name.
        @name.save if @name.changed?

        flash_notice(:runtime_name_description_success.t(id: @description.id))
        redirect_to(action: "show_name_description", id: @description.id)
      else
        flash_object_errors(@description)
      end
    end
  end

  def edit_name_description
    store_location
    pass_query_params
    @description = NameDescription.find(params[:id].to_s)
    @licenses = License.current_names_and_ids

    # check_description_edit_permission is partly broken.
    # It, LocationController, and NameController need repairs.
    # See https://www.pivotaltracker.com/story/show/174737948
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
        flash_notice(
          :runtime_edit_name_description_success.t(id: @description.id)
        )

        # Update name's classification cache.
        name = @description.name
        if (name.description == @description) &&
           (name.classification != @description.classification)
          name.classification = @description.classification
          name.save
        end

        # Log action to parent name.
        name.log(:log_description_updated,
                 touch: true,
                 user: @user.login,
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

        redirect_to(action: "show_name_description", id: @description.id)
      end
    end
  end

  def destroy_name_description
    pass_query_params
    @description = NameDescription.find(params[:id].to_s)
    if in_admin_mode? || @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.name.log(:log_description_destroyed,
                            user: @user.login,
                            touch: true,
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

  ##############################################################################
  #
  #  :section: Synonymy
  #
  ##############################################################################

  # Form accessible from show_name that lets a user review all the synonyms
  # of a name, removing others, writing in new, etc.
  def change_synonyms
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
      flash_notice(:name_change_synonyms_confirm.t)
    else
      # Go through list of all synonyms for this name and written-in names.
      # Exclude any names that have un-checked check-boxes: newly written-in
      # names will not have a check-box yet, names written-in in previous
      # attempt to submit this form will have checkboxes and therefore must
      # be checked to proceed -- the default initial state.
      proposed_synonyms = params[:proposed_synonyms] || {}
      sorter.all_synonyms.each do |n|
        # It is possible these names may be changed by transfer_synonym,
        # but these *instances* will not reflect those changes, so reload.
        @name.transfer_synonym(n.reload) if proposed_synonyms[n.id.to_s] != "0"
      end

      # De-synonymize any old synonyms in the "existing synonyms" list that
      # have been unchecked.  This creates a new synonym to connect them if
      # there are multiple unchecked names -- that is, it splits this
      # synonym into two synonyms, with checked names staying in this one,
      # and unchecked names moving to the new one.
      split_off_desynonymized_names(@name, params[:existing_synonyms] || {})

      # Deprecate everything if that check-box has been marked.
      success = true
      if @deprecate_all
        sorter.all_names.each do |n|
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
    @synonym_names    = @synonym_name_ids.map { |id| Name.safe_find(id) }.
                        reject(&:nil?)
  end

  # Form accessible from show_name that lets the user deprecate a name in favor
  # of another name.
  def deprecate_name
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
      flash_error(:runtime_name_deprecate_must_choose.t)
      return
    end

    # Find the chosen preferred name.
    @names = if params[:chosen_name][:name_id] &&
                (name = Name.safe_find(params[:chosen_name][:name_id]))
               [name]
             else
               Name.find_names_filling_in_authors(@what)
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

      # Merge this name's synonyms with the preferred name's synonyms.
      @name.merge_synonyms(target_name)

      # Change target name to "undeprecated".
      target_name.change_deprecated(false)
      target_name.save_with_log(:log_name_approved,
                                other: @name.real_search_name)

      # Change this name to "deprecated", set correct spelling, add note.
      @name.change_deprecated(true)
      @name.mark_misspelled(target_name) if @misspelling
      @name.save_with_log(:log_name_deprecated,
                          other: target_name.real_search_name)
      post_comment(:deprecate, @name, @comment) if @comment.present?

      redirect_with_query(action: "show_name", id: @name.id)
    end
  end

  # Form accessible from show_name that lets a user make call this an accepted
  # name, possibly deprecating its synonyms at the same time.
  def approve_name
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
    return unless params[:comment] && params[:comment][:comment]

    comment = params[:comment][:comment].to_s.strip_squeeze
    return unless comment != ""

    post_comment(:approve, @name, comment)
  end

  # Helper used by change_synonyms.  Deprecates a single name.  Returns true
  # if it worked.  Flashes an error and returns false if it fails for whatever
  # reason.
  def deprecate_synonym(name)
    return true if name.deprecated

    begin
      name.change_deprecated(true)
      name.save_with_log(:log_deprecated_by)
    rescue RuntimeError => e
      flash_error(e.to_s) if e.present?
      false
    end
  end

  # If changing the synonyms of a name that already has synonyms, the user is
  # presented with a list of "existing synonyms".  This is a list of check-
  # boxes.  They all start out checked.  If the user unchecks one, then that
  # name is removed from this synonym.  If the user unchecks several, then a
  # new synonym is created to synonymize all those names.
  def split_off_desynonymized_names(main_name, checks)
    first_group = main_name.synonyms
    other_group = first_group.select do |n|
      (n != main_name) && (checks[n.id.to_s] == "0")
    end
    return if other_group.empty?

    pick_one = other_group.shift
    pick_one.clear_synonym
    other_group.each { |n| pick_one.transfer_synonym(n) }
    main_name.clear_synonym if main_name.reload.synonyms.count <= 1
  end

  def dump_sorter(sorter)
    logger.warn(
      "tranfer_synonyms: only_single_names or only_approved_synonyms is false"
    )
    logger.warn("New names:")
    sorter.new_line_strs.each do |n|
      logger.warn(n)
    end
    logger.warn("\nSingle names:")
    sorter.single_line_strs.each do |n|
      logger.warn(n)
    end
    logger.warn("\nMultiple names:")
    sorter.multiple_line_strs.each do |n|
      logger.warn(n)
    end
    if sorter.chosen_names
      logger.warn("\nChosen names:")
      sorter.chosen_names.each do |n|
        logger.warn(n)
      end
    end
    logger.warn("\nSynonym names:")
    sorter.all_synonyms.map(&:id).each do |n|
      logger.warn(n)
    end
  end

  # Post a comment after approval or deprecation if the user entered one.
  def post_comment(action, name, message)
    summary = :"name_#{action}_comment_summary".l
    Comment.create!(target: name,
                    summary: summary,
                    comment: message)
  end

  ############################################################################
  #
  #  :section: EOL Feed
  #
  ############################################################################

  # Show the data getting sent to EOL
  def eol_preview
    @timer_start = Time.current
    eol_data(NameDescription.review_statuses.values_at(:unvetted, :vetted))
    @timer_end = Time.current
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
    image_data = Name.connection.select_all(%(
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
    ))
    image_data = image_data.to_a

    # Fill in @image_data, @users, and @licenses.
    image_data.each do |row|
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
    @timer_start = Time.current
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
  def eol
    @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
    @timer_start = Time.current
    @data = EolData.new
    render_xml(layout: false)
  end

  ##############################################################################
  #
  #  :section: Other Stuff
  #
  ##############################################################################

  # Utility accessible from a number of name pages (e.g. indexes and
  # show_name?) that lets you enter a whole list of names, together with
  # synonymy, and create them all in one blow.
  def bulk_name_edit
    @list_members = nil
    @new_names    = nil
    return unless request.method == "POST"

    list = params[:list][:members]&.strip_squeeze if params[:list]
    construct_approved_names(list, params[:approved_names])
    sorter = NameSorter.new
    sorter.sort_names(list)
    if sorter.only_single_names
      sorter.create_new_synonyms
      flash_notice(:name_bulk_success.t)
      redirect_to(controller: "observer", action: "list_rss_logs")
    else
      if sorter.new_name_strs != []
        # This error message is no longer necessary.
        if Rails.env.test?
          flash_error(
            "Unrecognized names given, including: "\
            "#{sorter.new_name_strs[0].inspect}"
          )
        end
      else
        # Same with this one... err, no this is not reported anywhere.
        flash_error(
          "Ambiguous names given, including: "\
          "#{sorter.multiple_line_strs[0].inspect}"
        )
      end
      @list_members = sorter.all_line_strs.join("\r\n")
      @new_names    = sorter.new_name_strs.uniq.sort
    end
  end

  # Draw a map of all the locations where this name has been observed.
  def map
    pass_query_params
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name

    @query = create_query(:Observation, :all, names: @name.id)
    apply_content_filters(@query)
    @observations = @query.results(include: :location).
                           select { |o| o.lat || o.location }
  end

  # Form accessible from show_name that lets a user setup tracker notifications
  # for a name.
  def email_tracking
    pass_query_params
    name_id = params[:id].to_s
    @name = find_or_goto_index(Name, name_id)
    return unless @name

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
        @notification = Notification.new(flavor: :name,
                                         user: @user,
                                         obj_id: name_id,
                                         note_template: note_template)
        flash_notice(:email_tracking_now_tracking.t(name: @name.display_name))
      else
        @notification.note_template = note_template
        flash_notice(:email_tracking_updated_messages.t)
      end
      notify_admins_of_notification(@notification)
      @notification.save
    when :DISABLE.l
      @notification.destroy
      flash_notice(
        :email_tracking_no_longer_tracking.t(name: @name.display_name)
      )
    end
    redirect_with_query(action: "show_name", id: name_id)
  end

  def notify_admins_of_notification(notification)
    return if notification.note_template.blank?
    return if !notification.new_record? &&
              notification.note_template_before_last_save.blank?

    user = notification.user
    name = Name.find(notification.obj_id)
    note = notification.note_template
    subject = "New Notification with Template"
    content = "User: ##{user.id} / #{user.login}\n" \
              "Name: ##{name.id} / #{name.search_name}\n" \
              "Note: [[#{note}]]"
    WebmasterEmail.build(user.email, content, subject).deliver_now
  end

  def edit_lifeform
    pass_query_params
    @name = find_or_goto_index(Name, params[:id])
    return unless request.method == "POST"

    words = Name.all_lifeforms.select do |word|
      params["lifeform_#{word}"] == "1"
    end
    @name.update(lifeform: " #{words.join(" ")} ")
    redirect_with_query(@name.show_link_args)
  end

  def propagate_lifeform
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
end
