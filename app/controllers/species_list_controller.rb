# encoding: utf-8
#
#  = Species List Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  index_species_list::                   List of lists in current query.
#  list_species_lists::                   List of lists by date.
#  species_lists_by_title::               List of lists by title.
#  species_lists_by_user::                List of lists created by user.
#  show_species_list::                    Display notes/etc. and list of species.
#  prev_species_list::                    Display previous species list in index.
#  next_species_list::                    Display next species list in index.
#  make_report::                          Display contents of species list as report.
#  create_species_list::                  Create new list.
#  name_lister::                          Efficient javascripty way to build a list of names.
#  edit_species_list::                    Edit existing list.
#  upload_species_list::                  Same as edit_species_list but gets list from file.
#  destroy_species_list::                 Destroy list.
#  manage_species_lists::                 Add/remove an observation from a user's lists.
#  add_observation_to_species_list::      (post method)
#  remove_observation_from_species_list:: (post method)
#
#  ==== Helpers
#  calc_checklist::                       Get list of names for LHS of form_species_list.
#  process_species_list::                 Create/update species list using form data.
#  construct_observations::               Create observations for new names added to list.
#  find_chosen_name::                     (helper)
#  render_name_list_as_txt::              Display list as text file.
#  render_name_list_as_rtf::              Display list as richtext file.
#  render_name_list_as_csv::              Display list as csv spreadsheet.
#
#  *NOTE*: There is some ambiguity between observations and names that makes
#  this slightly confusing.  The end result of a species list is actually a
#  list of Observation's, not Name's.  However, creation and editing is
#  generally accomplished via Name's alone (although see manage_species_lists
#  for the one exception).  In the end all these Name's cause rudimentary
#  Observation's to spring into existence.
#
################################################################################

class SpeciesListController < ApplicationController
  require 'rtf'

  before_filter :login_required, :except => [
    :index_species_list,
    :list_species_lists,
    :make_report,
    :name_lister,
    :next_species_list,
    :prev_species_list,
    :show_species_list,
    :species_list_search,
    :species_lists_by_title,
    :species_lists_by_user,
  ]

  before_filter :disable_link_prefetching, :except => [
    :create_species_list,
    :edit_species_list,
    :manage_species_lists,
    :show_species_list,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Display list of selected species_lists, based on current Query.  (Linked
  # from show_species_list, next to "prev" and "next".)
  def index_species_list # :nologin: :norobots:
    query = find_or_create_query(:SpeciesList, :by => params[:by])
    show_selected_species_lists(query, :id => params[:id],
                                :always_index => true)
  end

  # Display list of all species_lists, sorted by date.  (Linked from left
  # panel.)
  def list_species_lists # :nologin:
    query = create_query(:SpeciesList, :all, :by => :date)
    show_selected_species_lists(query, :id => params[:id], :by => params[:by])
  end

  # Display list of user's species_lists, sorted by date.  (Linked from left
  # panel.)
  def species_lists_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id]) : @user
      query = create_query(:SpeciesList, :by_user, :user => user)
      show_selected_species_lists(query)
    end
  end

  # Display list of all species_lists, sorted by title.  (Linked from left
  # panel.)
  def species_lists_by_title # :nologin: :norobots:
    query = create_query(:SpeciesList, :all, :by => :title)
    show_selected_species_lists(query)
  end

  # Display list of SpeciesList's whose title, notes, etc. matches a string pattern.
  def species_list_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (spl = SpeciesList.safe_find(pattern))
      redirect_to(:action => 'show_species_list', :id => spl.id)
    else
      query = create_query(:SpeciesList, :pattern_search, :pattern => pattern)
      show_selected_species_lists(query)
    end
  end

  # Show selected list of species_lists.
  def show_selected_species_lists(query, args={})
    @links ||= []
    args = {
      :action => :list_species_lists,
      :num_per_page => 20,
      :include => [:location, :user],
      :letters => 'species_lists.title'
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['title',   :sort_by_title.t],
      ['date',    :sort_by_date.t],
      ['user',    :sort_by_user.t],
      ['created', :sort_by_created.t],
      [(query.flavor == :by_rss_log ? 'rss_log' : 'modified'),
                  :sort_by_modified.t],
    ]

    # Paginate by letter if sorting by user.
    if (query.params[:by] == 'user') or
       (query.params[:by] == 'reverse_user')
      args[:letters] = 'users.login'
    # Can always paginate by title letter.
    else
      args[:letters] = 'species_lists.title'
    end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show and Edit Species Lists
  #
  ##############################################################################

  # Linked from: list_species_lists, show_observation, create/edit_species_list, etc. etc.
  # Inputs: params[:id] (species_list)
  # Outputs: @species_list, @observation_list
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list # :nologin: :prefetch:
    store_location
    clear_query_in_session
    pass_query_params
    if @species_list = find_or_goto_index(SpeciesList, params[:id],
                                          :include => :user)
      @query = create_query(:Observation, :in_species_list, :by => :name,
                               :species_list => @species_list)
      store_query_in_session(@query) if !params[:set_source].blank?
      @query.need_letters = 'names.text_name'
      @pages = paginate_letters(:letter, :page, 100)
      @objects = @query.paginate(@pages, :include => [:user, :name, :location, {:thumb_image => :image_votes}])
    end
  end

  # Go to next species_list: redirects to show_species_list.
  def next_species_list # :nologin: :norobots:
    redirect_to_next_object(:next, SpeciesList, params[:id])
  end

  # Go to previous species_list: redirects to show_species_list.
  def prev_species_list # :nologin: :norobots:
    redirect_to_next_object(:prev, SpeciesList, params[:id])
  end

  # Form for creating a new species list.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs:
  #   @checklist_names
  #   @species_list
  #   @list_members
  #   @new_names
  #   @multiple_names
  #   @deprecated_names
  #   @member_notes
  #   @place_name
  #   session[:checklist_source]
  def create_species_list # :prefetch: :norobots:
    @species_list = SpeciesList.new
    # for key in params[:species_list].keys().sort()
    #   flash_notice("#{key}: #{params[:species_list][key]}")
    # end
    if request.method != :post
      @checklist_names   = {}
      @new_names         = []
      @multiple_names    = []
      @deprecated_names  = []
      @list_members      = nil
      @member_vote       = Vote.maximum_vote
      @member_notes      = nil
      @member_lat        = nil
      @member_long       = nil
      @member_alt        = nil
      @member_is_collection_location = true
      @member_specimen   = false
      if !params[:clone].blank? and
         (clone = SpeciesList.safe_find(params[:clone]))
        query = create_query(:Observation, :in_species_list,
                             :species_list => clone)
        @checklist = calc_checklist(query)
        @species_list.when     = clone.when
        @species_list.where    = clone.where
        @species_list.location = clone.location
        @species_list.title    = clone.title
      else
        @checklist = calc_checklist
      end
    else
      process_species_list('created')
    end
  end

  # Form to edit species list.
  # Linked from: show/upload_species_list
  # Inputs:
  #   params[:id] (species_list)
  # Outputs:
  #   @checklist_names
  #   @species_list
  #   @list_members
  #   @new_names
  #   @multiple_names
  #   @deprecated_names
  #   @member_notes
  #   @place_name
  #   session[:checklist_source]
  def edit_species_list # :prefetch: :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id])
      if !check_permission!(@species_list)
        redirect_to(:action => 'show_species_list', :id => @species_list)
      elsif request.method != :post
        @checklist_names   = {}
        @list_members      = nil
        @member_vote       = Vote.maximum_vote
        @member_notes      = nil
        @member_lat        = nil
        @member_long       = nil
        @member_alt        = nil
        @member_is_collection_location = true
        @member_specimen   = false
        @new_names         = []
        @multiple_names    = []
        @deprecated_names  = @species_list.names.select(&:deprecated)
        @checklist         = calc_checklist
        @place_name        = @species_list.place_name
        if obs = @species_list.observations.last
          @member_vote       = obs.namings.first.users_vote(@user).value rescue Vote.maximum_vote
          @member_notes      = obs.notes
          @member_lat        = obs.lat
          @member_long       = obs.long
          @member_alt        = obs.alt
          @member_is_collection_location = obs.is_collection_location
          @member_specimen   = obs.specimen
        end
      else
        process_species_list('updated')
      end
    end
  end

  # Form to let user create/edit species_list from file.
  # Linked from: edit_species_list
  # Inputs: params[:id] (species_list)
  #   params[:species_list][:file]
  # Get: @species_list
  # Post: goes to edit_species_list
  def upload_species_list # :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id])
      if !check_permission!(@species_list)
        redirect_to(:action => 'show_species_list', :id => @species_list)
      elsif request.method == :get
        query = create_query(:Observation, :in_species_list, :by => :name,
                             :species_list => @species_list)
        @observation_list = query.results
      else
        file_data = params[:species_list][:file]
        @species_list.file = file_data
        sorter = NameSorter.new
        @species_list.process_file_data(sorter)
        @list_members     = sorter.all_line_strs.join("\r\n")
        @new_names        = sorter.new_name_strs.uniq.sort
        @multiple_names   = sorter.multiple_names.uniq.sort_by(&:text_name)
        @deprecated_names = sorter.deprecated_names.uniq.sort_by(&:search_name)
        @checklist_names  = {}
        @member_notes     = ''
        render(:action => 'edit_species_list')
      end
    end
  end

  # Callback to destroy a list.
  # Linked from: show_species_list
  # Inputs: params[:id] (species_list)
  # Redirects to list_species_lists.
  def destroy_species_list # :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id])
      if check_permission!(@species_list)
        @species_list.destroy
        Transaction.delete_species_list(:id => @species_list)
        flash_notice(:runtime_species_list_destroy_success.t(:id => params[:id]))
        redirect_to(:action => 'list_species_lists')
      else
        redirect_to(:action => 'show_species_list', :id => @species_list)
      end
    end
  end

  # Form to let user add/remove an observation from his various lists.
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Outputs: @observation
  def manage_species_lists # :prefetch: :norobots:
    @observation = find_or_goto_index(Observation, params[:id],
                                      :include => :species_lists)
    @all_lists = SpeciesList.find_all_by_user_id(@user.id)
    #                                            :order => "`modified' DESC")
  end

  # Remove an observation from a species_list.
  # Linked from: manage_species_lists
  # Inputs:
  #   params[:species_list]
  #   params[:observation]
  # Redirects back to manage_species_lists.
  def remove_observation_from_species_list # :norobots:
    if species_list = find_or_goto_index(SpeciesList, params[:species_list],
                                         :include => :observations)
      if observation = find_or_goto_index(Observation, params[:observation])
        if check_permission!(species_list)
          if species_list.observations.include?(observation)
            species_list.observations.delete(observation)
            Transaction.put_species_list(
              :id              => species_list,
              :del_observation => observation
            )
          end
          flash_notice(:runtime_species_list_remove_observation_success.t(
            :name => species_list.unique_format_name, :id => observation.id))
          redirect_to(:action => 'manage_species_lists', :id => observation.id)
        else
          redirect_to(:action => 'show_species_list', :id => species_list.id)
        end
      end
    end
  end

  # Add an observation to a species_list.
  # Linked from: manage_species_lists
  # Inputs:
  #   params[:species_list]
  #   params[:observation]
  # Redirects back to manage_species_lists.
  def add_observation_to_species_list # :norobots:
    if species_list = find_or_goto_index(SpeciesList, params[:species_list],
                                         :include => :observations)
      if observation = find_or_goto_index(Observation, params[:observation])
        if check_permission!(species_list)
          if !species_list.observations.include?(observation)
            species_list.observations << observation
            Transaction.put_species_list(
              :id              => species_list,
              :add_observation => observation
            )
          end
          flash_notice(:runtime_species_list_add_observation_success.t(
            :name => species_list.unique_format_name, :id => observation.id))
          redirect_to(:action => 'manage_species_lists', :id => observation.id)
        end
      end
    end
  end

  # Bulk-edit observations (at least the ones owned by this user) in a (any) species list.
  # Linked from: show_species_lists
  # Inputs:
  #   params[:id]
  #   params[:observation][id][:value]
  #   params[:observation][id][:when]
  #   params[:observation][id][:place_name]
  #   params[:observation][id][:notes]
  #   params[:observation][id][:lat]
  #   params[:observation][id][:long]
  #   params[:observation][id][:alt]
  #   params[:observation][id][:is_collection_location]
  #   params[:observation][id][:specimen]
  # Redirects back to show_species_lists.
  def bulk_editor # :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id])
      @query = create_query(:Observation, :in_species_list, :by => :id, :species_list => @species_list,
                            :where => "observations.user_id = #{@user.id}")
      @pages = paginate_numbers(:page, 100)
      @observations = @query.paginate(@pages, :include => [:comments, :images, :location, :namings => :votes])
      @observation = {}
      @votes = {}
      for obs in @observations
        @observation[obs.id] = obs
        vote = obs.consensus_naming.users_vote(@user) rescue nil
        @votes[obs.id] = vote || Vote.new
      end
      @vote_menu = translate_menu(Vote.confidence_menu)
      @no_vote = Vote.new
      @no_vote.value = 0
      if @observation.empty?
        flash_error(:species_list_bulk_editor_you_own_no_observations.t)
        redirect_to(:action => 'show_species_list', :id => @species_list.id)
      elsif request.method == :post
        updates = 0
        stay_on_page = false
        for obs in @observations
          args = params[:observation][obs.id.to_s] || {}
          any_changes = false
          old_vote = @votes[obs.id].value rescue 0
          if !args[:value].nil? and args[:value].to_s != old_vote.to_s
            if obs.namings.empty?
              obs.namings.create!(:user => @user, :name_id => obs.name_id)
            end
            if naming = obs.consensus_naming
              obs.change_vote(naming, args[:value].to_i, @user)
              any_changes = true
              @votes[obs.id].value = args[:value]
            else
              flash_warning(:species_list_bulk_editor_ambiguous_namings.t(:id => obs.id, :name => obs.name.display_name.t))
            end
          end
          for method in [:when_str, :place_name, :notes, :lat, :long, :alt,
                         :is_collection_location, :specimen]
            if !args[method].nil?
              old_val = obs.send(method)
              old_val = old_val.to_s if [:lat, :long, :alt].member?(method)
              new_val = args[method]
              new_val = (new_val == '1') if [:is_collection_location, :specimen].member?(method)
              if old_val != new_val
                obs.send("#{method}=", new_val)
                any_changes = true
              end
            end
          end
          if any_changes
            if obs.save
              updates += 1
            else
              flash_error('') if stay_on_page
              flash_error("#{:Observation.t} ##{obs.id}:")
              flash_object_errors(obs)
              stay_on_page = true
            end
          end
        end
        if !stay_on_page
          if updates == 0
            flash_warning(:runtime_no_changes.t)
          else
            flash_notice(:species_list_bulk_editor_success.t(:n => updates))
          end
          redirect_to(:action => :show_species_list, :id => @species_list.id)
        end
      end
    end
  end

  ################################################################################
  #
  #  :section: Name Lister
  #
  ################################################################################

  # Specialized form for creating a new species list, at Darvin's request.
  # Linked from: create_species_list
  # Inputs:
  #  params[:results]
  # Outputs:
  #  @names
  def name_lister # :nologin: :norobots:

    # Names are passed in as string, one name per line.
    @names = (params[:results] || '').chomp.split("\n").map {|n| n.to_s.chomp}

    if request.method == :post
      @objs = @names.map do |str|
        str.sub!(/\*$/, '')
        name, author = str.split('|')
        if author
          Name.find_by_text_name_and_author(name, author)
        else
          Name.find_by_text_name(name)
        end
      end.select {|n| !n.nil?}

      case params[:commit]
      when :name_lister_submit_spl.l
        @checklist_names  = {}
        @list_members     = params[:results].gsub('|',' ').gsub('*','')
        @new_names        = []
        @multiple_names   = []
        @deprecated_names = []
        @member_notes     = nil
        clear_query_in_session
        calc_checklist
        render(:action => 'create_species_list')
      when :name_lister_submit_txt.l
        render_name_list_as_txt(@objs)
      when :name_lister_submit_rtf.l
        render_name_list_as_rtf(@objs)
      when :name_lister_submit_csv.l
        render_name_list_as_csv(@objs)
      else
        flash_error(:name_lister_bad_submit.t(:button => params[:commit]))
      end
    end
  end

  # Linked from: show_species_list
  # Inputs:
  #   params[:id] (species_list)
  #   params[:type] (file extension)
  def make_report # :nologin: :norobots:
    names = SpeciesList.find(params[:id]).names
    case params[:type]
    when 'txt'
      render_name_list_as_txt(names)
    when 'rtf'
      render_name_list_as_rtf(names)
    when 'csv'
      render_name_list_as_csv(names)
    else
      flash_error(:make_report_not_supported.t(:type => params[:type]))
      redirect_to(:action => "show_species_list", :id => params[:id])
    end
  end

  # Exception thrown if try to render a report in a charset we don't handle.
  class UnsupportedCharsetError < ArgumentError
  end

  # Display list of names as plain text.
  def render_name_list_as_txt(names, charset=nil)
    charset ||= 'UTF-8'
    charset = charset.upcase
    raise UnsupportedCharsetError if !['ASCII', 'ISO-8859-1', 'UTF-8'].include?(charset)
    str = names.map do |name|
      if !name.author.blank?
        name.text_name + ' ' + name.author
      else
        name.text_name
      end
    end.join("\r\n")
    str = case charset
      when 'ASCII'; str.to_ascii
      when 'UTF-8'; "\xEF\xBB\xBF" + str
      else str.iconv(charset)
    end
    send_data(str,
      :type => "text/plain; charset=#{charset}",
      :disposition => 'attachment; filename="report.txt"'
    )
  end

  # Display list of names as csv file.
  def render_name_list_as_csv(names, charset=nil)
    charset ||= 'ISO-8859-1'
    charset = charset.upcase
    raise UnsupportedCharsetError if !['ASCII', 'ISO-8859-1'].include?(charset)
    str = FasterCSV.generate do |csv|
      csv << ['name', 'author', 'citation', 'valid']
      names.each do |name|
        csv << [name.text_name, name.author, name.citation,
          name.deprecated ? '' : '1'].map {|v| v.blank? ? nil : v}
      end
    end
    str = case charset
      when 'UTF-8'; str
      when 'ASCII'; str.to_ascii
      else
        str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
        str.iconv(charset)
    end
    send_data(str,
      :type => "text/csv; charset=#{charset}; header=present",
      :disposition => 'attachment; filename="report.csv"'
    )
  end

  # Display list of names as rich text.
  def render_name_list_as_rtf(names)
    doc = RTF::Document.new(RTF::Font::SWISS)
    for name in names
      rank      = name.rank
      text_name = name.text_name
      author    = name.author
      if name.deprecated
        node = doc
      else
        node = doc.bold
      end
      if [:Genus, :Species, :Subspecies, :Variety, :Form].include?(rank)
        node = node.italic
      end
      node << text_name
      doc << " " + author if !author.blank?
      doc.line_break
    end
    send_data(doc.to_rtf,
      :type => 'text/rtf; charset=ISO-8859-1',
      :disposition => 'attachment; filename="report.rtf"'
    )
  end

  ################################################################################
  #
  #  :section: Helpers
  #
  ################################################################################

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
  #   params[:member][:vote]
  #   params[:member][:notes]
  #   params[:member][:lat]
  #   params[:member][:long]
  #   params[:member][:alt]
  #   params[:member][:is_collection_location]
  #   params[:member][:specimen]
  #   params[:list][:members]               String that user typed in in big text area on right side (squozen and stripped).
  #   params[:approved_names]               List of new names from prev post.
  #   params[:approved_deprecated_names]    List of deprecated names from prev post.
  #   params[:chosen_multiple_names][name]  Radio boxes allowing user to choose among ambiguous names.
  #   params[:chosen_approved_names][name]  Radio boxes allowing user to choose accepted names.
  #     (Both the last two radio boxes are hashes with:
  #       key: ambiguous name as typed with nonalphas changed to underscores,
  #       val: id of name user has chosen (via radio boxes in feedback)
  #   params[:checklist_data][...]          Radio boxes on left side: hash from name id to "1".
  #   params[:checklist_names][name_id]     (Used by view to give a name to each id in checklist_data hash.)
  # Success: redirects to show_species_list
  # Failure: redirects back to create_edit_species_list.
  def process_species_list(type_str)
    redirected = false
    args = params[:species_list]

    # Update the timestamps/user/when/where/title/notes fields.
    now = Time.now
    @species_list.created    = now if type_str == "created"
    @species_list.modified   = now
    @species_list.user       = @user
    @species_list.attributes = args
    if Location.is_unknown?(@species_list.place_name) or
       @species_list.place_name.blank?
      @species_list.location = Location.unknown
      @species_list.where = nil
    end

    # Validate place name.
    @place_name = @species_list.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] and @species_list.location.nil?
      db_name = Location.user_name(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
    end

    # This just makes sure all the names (that have been approved) exist.
    list = params[:list][:members].gsub('_', ' ').strip_squeeze
    construct_approved_names(list, params[:approved_names])

    # Initialize NameSorter and give it all the information.
    sorter = NameSorter.new
    sorter.add_chosen_names(params[:chosen_multiple_names])
    sorter.add_chosen_names(params[:chosen_approved_names])
    sorter.add_approved_deprecated_names(params[:approved_deprecated_names])
    sorter.check_for_deprecated_checklist(params[:checklist_data])
    sorter.check_for_deprecated_names(@species_list.names) if @species_list.id
    sorter.sort_names(list)

    # Now let us count all the ways in which NameSorter can fail...
    failed = false

    # Does list have "Name one = Name two" type lines?
    if sorter.has_new_synonyms
      flash_error(:runtime_species_list_need_to_use_bulk.t)
      sorter.reset_new_names
      failed = true
    end

    # Are there any unrecognized names?
    if sorter.new_name_strs != []
      flash_error "Unrecognized names given: '#{sorter.new_name_strs.map(&:to_s).join("', '")}'" if TESTING
      failed = true
    end

    # Are there any ambiguous names?
    if !sorter.only_single_names
      flash_error "Ambiguous names given: '#{sorter.multiple_line_strs.map(&:to_s).join("', '")}'" if TESTING
      failed = true
    end

    # Are there any deprecated names which haven't been approved?
    if sorter.has_unapproved_deprecated_names
      flash_error("Found deprecated names: #{sorter.deprecated_names.map(&:display_name).join(', ').t}") if TESTING
      failed = true
    end

    # Okay, at this point we've apparently validated the new list of names.
    # Save the OTHER changes to the species list, then let this other method
    # (construct_observations) update the members.  This always succeeds, so
    # we can redirect to show_species_list.
    if !failed and @dubious_where_reasons == []
      if !@species_list.save
        flash_object_errors(@species_list)
      else
        if type_str == 'created'
          Transaction.post_species_list(
            :id       => @species_list,
            :date     => @species_list.when,
            :location => @species_list.location || @species_list.where,
            :title    => @species_list.title,
            :notes    => @species_list.notes
          )
        else
          args = {}
          args[:date] = @species_list.when  if @species_list.when_changed?
          if @species_list.where_changed? || @species_list.location_id_changed?
            args[:location] = @species_list.location || @species_list.where
          end
          args[:title] = @species_list.title if @species_list.title_changed?
          args[:notes] = @species_list.notes if @species_list.notes_changed?
          if !args.empty?
            args[:id] = @species_list
            Transaction.put_species_list(args)
          end
        end

        construct_observations(@species_list, params, type_str, @user, sorter)

        if @species_list.location.nil?
          redirect_to(:controller => 'location', :action => 'create_location',
                      :where => @place_name, :set_species_list => @species_list.id)
        elsif has_unshown_notifications?(@user, :naming)
          redirect_to(:controller => 'observer', :action => 'show_notifications')
        else
          redirect_to(:action => 'show_species_list', :id => @species_list)
        end
        redirected = true
      end
    end

    # Failed to create due to synonyms, unrecognized names, etc.
    if !redirected
      @list_members      = sorter.all_line_strs.join("\r\n")
      @new_names         = sorter.new_name_strs.uniq.sort
      @multiple_names    = sorter.multiple_names.uniq.sort_by(&:text_name)
      @deprecated_names  = sorter.deprecated_names.uniq.sort_by(&:search_name)
      @checklist_names   = params[:checklist_data] || {}
      @member_vote       = (params[:member][:vote].to_s) rescue ''
      @member_notes      = (params[:member][:notes].to_s) rescue ''
      @member_lat        = (params[:member][:lat].to_s) rescue ''
      @member_long       = (params[:member][:long].to_s) rescue ''
      @member_alt        = (params[:member][:alt].to_s) rescue ''
      @member_is_collection_location = (params[:member][:is_collection_location] == '1') rescue true
      @member_specimen   = (params[:member][:specimen] == '1') rescue false
    end
  end

  # This is called only by create/edit_species_list.
  #
  # In the former case (create) it is called with nil, which tells it to use
  # session[:checklist_source], which is a Query id.
  #
  # In the latter case (edit) it is called with nil the first time through
  # (with the same results as above), and it's called with species_list.id
  # subsequent times (in which case it uses the existing contents of the
  # species list instead).
  #
  # The end result is simply to store an Array of these names in @checklist,
  # where the values are [observation_name, name_id].  This Array is used by
  # _form_species_lists.rhtml to create a list of names with check-boxes beside
  # them that you can add to the species list.)
  #
  def calc_checklist(query=nil)
    @checklist = []
    if query or (query = get_query_from_session)
      @checklist = case query.model_symbol

      when :Name
        query.select_rows(
          :select => 'DISTINCT names.observation_name, names.id',
          :limit  => 1000
        )

      when :Observation
        query.select_rows(
          :select => 'DISTINCT names.observation_name, names.id',
          :join   => :names,
          :limit  => 1000
        )

      when :Image
        query.select_rows(
          :select => 'DISTINCT names.observation_name, names.id',
          :join   => {:images_observations => {:observations => :names}},
          :limit  => 1000
        )

      when :Location
        query.select_rows(
          :select => 'DISTINCT names.observation_name, names.id',
          :join   => {:observations => :names},
          :limit  => 1000
        )

      when :RssLog
        query.select_rows(
          :select => 'DISTINCT names.observation_name, names.id',
          :join   => {:observations => :names},
          :where  => 'rss_logs.observation_id > 0',
          :limit  => 1000
        )

      else []
      end
    end
  end

  # This creates abd adds observations for any names not already in the list.
  # It fills in dates, location, and even notes as well as it can.  All saved.
  # Used by process_species_list.
  # Inputs:
  #   species_list      List we're adding observations to.
  #   type_str          For diagnostics: "created" or "updated".
  #   user              Owner of list.
  #   sorter            Names from the text list.
  #   params[:member][:vote]            Notes, etc. to use for new observations.
  #   params[:member][:notes]           
  #   params[:member][:lat]
  #   params[:member][:long]
  #   params[:member][:alt]
  #   params[:member][:is_collection_location]
  #   params[:member][:specimen]
  #   params[:chosen_approved_names]    Names from radio boxes.
  #   params[:checklist_data]           Names from LHS check boxes.
  def construct_observations(spl, params, type_str, user, sorter)
    spl.log("log_species_list_#{type_str}".to_sym)
    if type_str == 'created'
      flash_notice(:runtime_species_list_create_success.t(:id => spl.id))
    else
      flash_notice(:runtime_species_list_edit_success.t(:id => spl.id))
    end

    # Put together a list of arguments to use when creating new observations.
    sp_args = {
      :created  => spl.modified,
      :modified => spl.modified,
      :user     => user,
      :location => spl.location,
      :where    => spl.where,
      :vote     => params[:member][:vote],
      :notes    => params[:member][:notes].to_s,
      :lat      => params[:member][:lat].to_s,
      :long     => params[:member][:long].to_s,
      :alt      => params[:member][:alt].to_s,
      :is_collection_location => (params[:member][:is_collection_location] == '1'),
      :specimen => (params[:member][:specimen] == '1'),
    }

    # This updates certain observation namings already in the list.  It looks
    # for namings that are deprecated, then replaces them with approved
    # synonyms which the user has chosen via radio boxes in
    # params[:chosen_approved_names].
    if chosen_names = params[:chosen_approved_names]
      for observation in spl.observations
        for naming in observation.namings
          # (compensate for gsub in _form_species_lists)
          if alt_name_id = chosen_names[naming.name_id.to_s]
            alt_name = Name.find(alt_name_id)
            naming.name = alt_name
            naming.save
            Transaction.put_naming(
              :id       => naming,
              :set_name => alt_name
            )
          end
        end
      end
    end

    # Add all names from text box into species_list.  Creates a new observation
    # for each name.  ("single names" are names that matched a single name
    # uniquely.)
    for name, timestamp in sorter.single_names
      sp_args[:when] = timestamp || spl.when
      sp_args2 = sp_args.dup.merge(:what => name)
      spl.construct_observation(sp_args2)
    end

    # Add checked names from LHS check boxes.  It doesn't check if they are
    # already in there; it creates new observations for each and stuffs it in.
    sp_args[:when] = spl.when
    if params[:checklist_data]
      for key, value in params[:checklist_data]
        if value == "1"
          name = find_chosen_name(key.to_i, params[:chosen_approved_names])
          sp_args2 = sp_args.dup.merge(:what => name)
          spl.construct_observation(sp_args2)
        end
      end
    end
  end

  # Finds name for id, looking up synonyms already chosen in radio boxes.
  # (alternatives hash comes from params[:chosen_approved_names])
  # Helper for construct_observations.
  def find_chosen_name(id, alternatives)
    if alternatives and
       (alt_id = alternatives[id.to_s])
      Name.find(alt_id)
    else
      Name.find(id)
    end
  end
end
