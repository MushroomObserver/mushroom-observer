# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class NamesController < ApplicationController
  before_action :store_location, except: [:index]
  before_action :pass_query_params, except: [:index]
  before_action :login_required

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::Names.default_order # :name
  end

  # ApplicationController uses this to dispatch #index to a private method
  def index_active_params
    [:advanced_search, :pattern, :has_observations, :has_descriptions,
     :needs_description, :by_user, :by_editor, :by, :q, :id].freeze
  end

  # Displays list of advanced search results.
  def advanced_search
    return if handle_advanced_search_invalid_q_param?

    query = find_query(:Name)
    # Would have to check this here because we're not running the query yet.
    raise(:runtime_no_conditions.l) unless query&.params&.any?

    [query, {}]
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(search_advanced_path)
    [nil, {}]
  end

  # Display list of names that match a string.
  def pattern
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) &&
       (name = Name.safe_find(pattern))
      redirect_to(name_path(name.id))
      [nil, {}]
    else
      show_non_id_pattern_results(pattern)
    end
  end

  def show_non_id_pattern_results(pattern)
    # Have to use PatternSearch here to catch invalid PatternSearch terms.
    # Can't just send pattern to Query as create_query(:Observation, pattern:)
    search = PatternSearch::Name.new(pattern)
    if search.errors.any?
      search.errors.each do |error|
        flash_error(error.to_s)
      end
      render("names/index")
      [nil, {}]
    else
      # Call create_query to apply user content filters
      query = create_query(:Name, search.query.params)
      make_name_suggestions(search)
      [query, {}]
    end
  end

  def make_name_suggestions(search)
    alternate_spellings = search.query.params[:pattern]
    return unless alternate_spellings && @objects.empty?

    @name_suggestions =
      Name.suggest_alternate_spellings(alternate_spellings)
  end

  # Disabling the cop because subaction methods are going away soon
  # rubocop:disable Naming/PredicatePrefix
  # Display list of names that have observations.
  def has_observations
    query = create_query(:Name, has_observations: 1)
    [query, {}]
  end

  # Display list of names with descriptions that have authors.
  def has_descriptions
    @has_descriptions = true # signals to add desc info to name list
    query = create_query(:Name, has_descriptions: 1)
    [query, {}]
  end
  # rubocop:enable Naming/PredicatePrefix

  # Display list of the most popular 100 names that don't have descriptions.
  # NOTE: all this extra info and help will be lost if user re-sorts.
  def needs_description
    @help = :needed_descriptions_help
    query = create_query(:Name, needs_description: 1)
    [query, { num_per_page: 100 }]
  end

  # Display list of names that a given user is author on.
  def by_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_user].to_s,
      index_path: names_path
    )
    return unless user

    query = create_query(:Name, by_users: user)
    [query, {}]
  end

  # Display list of names that a given user is editor on.
  def by_editor
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_editor].to_s,
      index_path: names_path
    )
    return unless user

    query = create_query(:Name, by_editor: user)
    [query, {}]
  end

  # Hook runs before template displayed. Must return query.
  def filtered_index_final_hook(query, _display_opts)
    store_query_in_session(query)
    query
  end

  def index_display_opts(opts, _query)
    {
      letters: true,
      num_per_page: (/^[a-z]/i.match?(params[:letter].to_s) ? 500 : 50),
      include: [:description]
    }.merge(opts)
  end

  ###################################

  public

  # Used to test pagination.
  def test_index
    query = find_query(:Name)
    raise("Missing query: #{params[:q]}") unless query

    if params[:test_anchor]
      @test_pagination_args = { anchor: params[:test_anchor] }
    end

    filtered_index(query, num_per_page: params[:num_per_page].to_i)
  end

  ##############################################################################
  #
  #  :section: Show Name
  #
  ##############################################################################

  # Show a Name, one of its NameDescription's, associated taxa, and a bunch of
  # relevant Observations.
  def show
    clear_query_in_session

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Name, params[:id].to_s)
    when "prev"
      redirect_to_next_object(:prev, Name, params[:id].to_s)
    end

    # Load Name and NameDescription along with a bunch of associated objects.
    return unless find_name!

    update_view_stats(@name)

    # Tell robots the proper URL to use to index this content.
    @canonical_url = "#{MO.http_domain}/names/#{@name.id}"

    init_projects_ivar
    init_related_query_ivars
  end

  # ----------------------------------------------------------------------------

  private

  def find_name!
    @name = Name.show_includes.safe_find(params[:id]) ||
            flash_error_and_goto_index(Name, params[:id])
  end

  # Possible sources of extra db lookups in partials

  # carousel:
  #   @best_images
  # best_description:
  #   @best_description
  # comments:
  #   comments_for_object
  # observations_menu:
  #   @has_subtaxa
  #   @subtaxa_query
  # nomenclature:
  #   approved_synonyms, deprecated_synonyms = name.sort_synonyms
  # classification:
  #   approved_name = @name.approved_name
  #   parents = approved_name.all_parents
  #   @first_child
  #   @children_query
  #   The entire name::synonymy module may be a candidate for a PORO
  # lifeform:
  #   @first_child
  # notes:
  # descriptions:
  #   description_links = list_descriptions(user: @user, object: @name,
  #                                         type: :name)
  # projects:
  #   @projects

  def init_related_query_ivars
    @versions = @name.versions
    @has_subtaxa = 0
    # Query for names of subtaxa, used in special query link
    # Note this is only creating a schematic of a query, used in the link.

    # Create query for immediate children.
    @children_query = create_query(
      :Name, names: { lookup: @name.id,
                      include_immediate_subtaxa: true,
                      exclude_original_names: true }
    )
    # @first_child runs @children_query to check for immediate children.
    # Used in classification and lifeform.
    # Potentially refactor to reduce duplicate queries:

    # First query: Names including immediate subtaxa.
    # Instead of running @children_query here, consider altering the original
    # show query to include_immediate_subtaxa (would need to write a complicated
    # scope, but it's outlined in app/classes/query/modules/lookup_names.rb).
    # Could select @name from those results using the original name.id, then
    # select @first_child from the rest.
    @first_child = @children_query.results(limit: 1).first

    # Possible query: Synonyms of name? Incompatible with first query.
    # Maybe use to find approved_synonyms, deprecated_synonyms, misspellings.
    # — Nope. Hardly causes any load time.

    # Second query: Observations of name including (all) subtaxa.
    # This is only used for the link to "observations of this name's subtaxa".
    # We also query for obs (with images) below, so we could maybe refactor to
    # get Observation.names(lookup: name.id, include_subtaxa: true).
    #     order(:vote_cache).
    # Then, select those of original name with thumb_image_id for @best_images,
    # and select_count all (excluding obs of original name) to get @has_subtaxa.
    # Would need to write include_subtaxa scope, as above.
    if @name.at_or_below_genus?
      @subtaxa_query = create_query(
        :Observation, names: { lookup: @name.id,
                               include_subtaxa: true,
                               exclude_original_names: true,
                               order_by: :confidence }
      )
      # Determine if relevant and count the results of running the query if so.
      # Don't run if there aren't any children.
      @has_subtaxa = if @first_child
                       @subtaxa_query.result_ids.count
                     else
                       0
                     end
    end

    # NOTE: `_observation_menu` makes many select_count queries like this!
    # That is where most of the heavy loading is. Check helpers/show_name_helper
    #
    # Third query (maybe combine with second)
    @obss = Name::Observations.new(@name)
    # This initiates a query for the images of only the most confident obs
    @best_images = @obss.best_images

    # This seems like it queries the NameDescription table.
    # Would be better to eager load descriptions and derive @best_description
    # from them. Can also derive @projects from this.
    @best_description = @name.best_brief_description
    # Save a lookup in comments_for_object
    @comments = @name.comments&.sort_by(&:created_at)&.reverse
  end

  def init_projects_ivar
    # Get a list of projects the user can create drafts for.
    @projects = @user&.projects_member&.select do |project|
      @name.descriptions.none? { |d| d.belongs_to_project?(project) }
    end
  end

  public

  def new
    init_create_name_form
  end

  def create
    init_create_name_form
    @parse = parse_name
    make_sure_name_doesnt_exist!
    create_new_name
  rescue RuntimeError => e
    reload_name_form_on_error(e)
  end

  def edit
    return unless find_name!

    init_edit_name_form
  end

  def update
    return unless find_name!

    init_edit_name_form
    update_name
  rescue RuntimeError => e
    reload_name_form_on_error(e)
  end

  private

  def init_create_name_form
    @name = Name.new
    @name.rank = "Species"
    @name_string = ""
  end

  def reload_name_form_on_error(err)
    flash_error(err.to_s) if err.present?
    flash_object_errors(@name)

    @name.attributes = permitted_name_params[:name]
    @name.deprecated = params[:name][:deprecated] == "true"
    @name_string     = params[:name][:text_name]
    render("new", location: new_name_path)
  end

  def init_edit_name_form
    if params[:name]
      @misspelling      = params[:name][:misspelling] == "1"
      @correct_spelling = params[:name][:correct_spelling].to_s.strip_squeeze
    else
      @misspelling      = @name.is_misspelling?
      @correct_spelling = if @misspelling
                            @name.correct_spelling.user_real_search_name(@user)
                          else
                            ""
                          end
    end
    @name_string = @name.user_real_text_name(@user)
  end

  # ------
  # create
  # ------

  def make_sure_name_doesnt_exist!
    matches = Name.matching_desired_new_parsed_name(@parse)
    if matches.one?
      raise(:runtime_name_create_already_exists.
              t(name: matches.first.user_display_name(@user)))
    elsif matches.many?
      raise(:create_name_multiple_names_match.t(
              str: @parse.user_real_search_name(@user)
            ))
    end
  end

  def create_new_name
    @name = Name.new_name_from_parsed_name(@parse)
    @name.user ||= @user
    set_unparsed_attrs
    unless @name.save_with_log(@user, :log_name_updated)
      raise(:runtime_unable_to_save_changes.t)
    end

    flash_notice(:runtime_create_name_success.t(
                   name: @name.user_real_search_name(@user)
                 ))
    update_ancestors
    redirect_to_show_name
  end

  def set_unparsed_attrs
    set_locked_if_admin
    set_icn_id_if_unlocked_or_admin
    @name.citation = params[:name][:citation].to_s.strip_squeeze
    @name.notes    = params[:name][:notes].to_s.strip
  end

  def set_locked_if_admin
    @name.locked   = params[:name][:locked].to_s == "1" if in_admin_mode?
  end

  def set_icn_id_if_unlocked_or_admin
    @name.icn_id   = params[:name][:icn_id] if editable_in_session?
  end

  # ------
  # update
  # ------

  def update_name
    @parse = parse_name
    if !minor_change? && @name.dependents? && !in_admin_mode?
      redirect_with_query(new_admin_emails_name_change_requests_path(
                            name_id: @name.id,
                            # Auricularia Bull. [#17132]
                            new_name_with_icn_id: "#{@parse.search_name} " \
                                                  "[##{params[:name][:icn_id]}]"
                          ))
      return
    end

    match = check_for_matches if editable_in_session?
    if match
      merge_names(match)
    else
      change_existing_name
    end
  end

  def editable_in_session?
    in_admin_mode? || !@name.locked
  end

  def check_for_matches
    matches = Name.where(search_name: @parse.search_name) - [@name]
    return matches.first unless matches.many?

    args = {
      str: @parse.user_real_search_name(@user),
      matches: matches.map(&:unique_search_name).join(" / ")
    }
    raise(:edit_name_multiple_names_match.t(args))
  end

  def change_existing_name
    any_changes = perform_change_existing_name
    if status_changing?
      redirect_to_approve_or_deprecate
    else
      flash_warning(:runtime_edit_name_no_change.t) unless any_changes
      redirect_to_show_name
    end
  end

  def status_changing?
    params[:name][:deprecated].to_s != @name.deprecated.to_s
  end

  def redirect_to_show_name
    redirect_with_query(@name.show_link_args)
  end

  def redirect_to_approve_or_deprecate
    if params[:name][:deprecated].to_s == "true"
      redirect_with_query(form_to_deprecate_synonym_of_name_path(@name.id))
    else
      redirect_with_query(form_to_approve_synonym_of_name_path(@name.id))
    end
  end

  def perform_change_existing_name
    update_correct_spelling
    set_name_author_and_rank
    set_unparsed_attrs
    if !@name.changed?
      any_changes = false
    elsif !@name.save_with_log(@user, :log_name_updated)
      raise(:runtime_unable_to_save_changes.t)
    else
      flash_notice(:runtime_edit_name_success.t(
                     name: @name.user_real_search_name(@user)
                   ))
      any_changes = true
    end
    # Update ancestors regardless whether name changed; maybe this will add
    # missing ancestors in case database is messed up. But don't update
    # ancestors if non-admin is changing locked namge because that would create
    # bogus name and ancestors if @parse.search_name differs from @name
    update_ancestors if editable_in_session?
    any_changes
  end

  # Update the misspelling status.
  #
  # @name::             Name whose status we're changing.
  # @misspelling::      Boolean: is the "this is misspelt" box checked?
  # @correct_spelling:: String: the correct name, as entered by the user.
  #
  # 1) If the checkbox is unchecked, and name used to be misspelt, then it
  #    clears correct_spelling_id.
  # 2) Otherwise, if the text field is filled in it looks up the name and
  #    sets correct_spelling_id.
  #
  # All changes are made (but not saved) to +@name+.  It returns true if
  # everything went well.  If it couldn't recognize the correct name, it
  # changes nothing and raises a RuntimeError.
  #
  def update_correct_spelling
    return unless editable_in_session?

    if @name.is_misspelling? && (!@misspelling || @correct_spelling.blank?)
      @name.correct_spelling = nil
      @parse = parse_name # update boldness in @parse.params
    elsif @correct_spelling.present?
      set_correct_spelling
      @parse = parse_name # update boldness in @parse.params
    end
  end

  def set_correct_spelling
    correct_name = Name.find_names_filling_in_authors(@user,
                                                      @correct_spelling).first
    raise(:runtime_form_names_misspelling_bad.t) unless correct_name
    raise(:runtime_form_names_misspelling_same.t) if correct_name.id == @name.id

    @name.mark_misspelled(@user, correct_name)
    # (This tells it not to redirect to "approve".)
    params[:name][:deprecated] = "true"
  end

  def parse_name
    text_name = parsed_text_name
    author = params[:name][:author]
    in_str = Name.clean_incoming_string("#{text_name} #{author}")
    in_rank = params[:name][:rank]
    old_deprecated = @name ? @name.deprecated : false
    parse = Name.parse_name(in_str, rank: in_rank, deprecated: old_deprecated)
    if !parse || parse.rank != in_rank
      rank_tag = :"rank_#{in_rank.to_s.downcase}"
      raise(:runtime_invalid_for_rank.t(rank: rank_tag, name: in_str))
    end
    parse
  end

  def parsed_text_name
    if params[:name][:text_name].blank? && @name&.text_name.present?
      @name.user_real_text_name(@user)
    else
      params[:name][:text_name]
    end
  end

  def set_name_author_and_rank
    return unless editable_in_session?

    email_admin_name_change unless minor_change?
    @name.attributes = @parse.params
  end

  def minor_change?
    return false if icn_id_conflict?(params[:name][:icn_id])
    return true if just_adding_author?

    old_name = @name.user_real_search_name(@user)
    new_name = @parse.user_real_search_name(@user)
    new_name.percent_match(old_name) > 0.9
  end

  def icn_id_conflict?(new_icn_id)
    new_icn_id && @name.icn_id &&
      new_icn_id.to_s != @name.icn_id.to_s
  end

  def just_adding_author?
    @name.author.blank? && @parse.text_name == @name.text_name
  end

  def update_ancestors
    Name.find_or_create_parsed_name_and_parents(@user, @parse).each do |name|
      name.save_with_log(@user, :log_name_created) if name&.new_record?
    end
  end

  def email_admin_name_change
    content = email_name_change_content
    QueuedEmail::Webmaster.create_email(
      @user,
      subject: "Nontrivial Name Change",
      content: content
    )
    NamesControllerUpdateTest.report_email(content) if Rails.env.test?
  end

  def email_name_change_content
    :email_name_change.l(
      user: @user.login,
      old_identifier: @name.icn_id,
      new_identifier: params[:name][:icn_id],
      old: @name.user_real_search_name(@user),
      new: @parse.user_real_search_name(@user),
      observations: @name.observations.length,
      namings: @name.namings.length,
      show_url: "#{MO.http_domain}/names/#{@name.id}",
      edit_url: "#{MO.http_domain}/names/#{@name.id}/edit"
    )
  end

  # -------------
  # update: merge
  # -------------

  def merge_names(new_name)
    if in_admin_mode? ||
       !@name.merger_destructive? || !new_name.merger_destructive?
      perform_merge_names(new_name)
      redirect_to_show_name
    else
      redirect_with_query(new_admin_emails_merge_requests_path(
                            type: :Name, old_id: @name.id, new_id: new_name.id
                          ))
    end
  end

  # Merge name being edited (@name) with the found name
  # The presumptive surviving id is that of the found name,
  # and the presumptive name to be destroyed is the name being edited.
  def perform_merge_names(survivor)
    # Name to displayed in the log "Name Destroyed" entry
    logged_destroyed_name = display_name_without_user_filter(@name)
    destroyed_real_search_name = @name.user_real_search_name(@user)

    prepare_presumptively_disappearing_name
    deprecation = change_deprecation_iff_user_requested

    # Reverse merger directidon if that's safer
    @name, survivor = survivor, @name if reverse_merger_safer?(survivor)

    # Force log to display the destroyed name
    @name.display_name = logged_destroyed_name
    survivor.change_deprecated(deprecation) unless deprecation.nil?

    # move associations to survivor, destroy @name object
    survivor.merge(@user, @name)

    send_merger_messages(destroyed_real_search_name: destroyed_real_search_name,
                         survivor: survivor)
    @name = survivor
    @name.current_user = @user
    @name.save
  end

  # User can filter out author in display name
  # But for logging and message purposes, we should include author
  def display_name_without_user_filter(name)
    name[:display_name]
  end

  def prepare_presumptively_disappearing_name
    @name.attributes = @parse.params
    set_unparsed_attrs
  end

  # nil if user did not request change_existing_name
  # else new deprecation status (true/false)
  def change_deprecation_iff_user_requested
    return nil unless @name.deprecated != (params[:name][:deprecated] == "true")

    !@name.deprecated
  end

  def reverse_merger_safer?(presumptive_survivor)
    @name.merger_destructive? && !presumptive_survivor.merger_destructive?
  end

  def send_merger_messages(destroyed_real_search_name:, survivor:)
    args = { this: destroyed_real_search_name,
             that: survivor.user_real_search_name(@user) }
    flash_notice(:runtime_edit_name_merge_success.t(args))
    email_admin_icn_id_conflict(survivor) if icn_id_conflict?(survivor.icn_id)
  end

  def email_admin_icn_id_conflict(survivor)
    content = :email_merger_icn_id_conflict.l(
      name: survivor.user_real_search_name(@user),
      surviving_icn_id: survivor.icn_id,
      deleted_icn_id: @name.icn_id,
      user: @user.login,
      show_url: "#{MO.http_domain}/names/#{@name.id}",
      edit_url: "#{MO.http_domain}/names/#{@name.id}/edit"
    )
    QueuedEmail::Webmaster.create_email(
      @user,
      subject: "Merger identifier conflict",
      content: content
    )
    NamesControllerUpdateMergeTest.report_email(content) if Rails.env.test?
  end

  # ----------------------------------------------------------------------------

  # allow some mass assignment for purposes of reloading form
  def permitted_name_params
    params.permit(name: [:author, :citation, :icn_id, :locked, :notes, :rank])
  end
end
# rubocop:enable Metrics/ClassLength
