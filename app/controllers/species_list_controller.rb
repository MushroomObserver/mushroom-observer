# encoding: utf-8
#
#  = Species List Controller
#
#  == Actions
#
#  index_species_list::                   List of lists in current query.
#  list_species_lists::                   List of lists by date.
#  species_lists_by_title::               List of lists by title.
#  species_lists_by_user::                List of lists created by user.
#  species_list_search::                  List of lists matching search.
#
#  show_species_list::                    Display notes/etc. and list of species.
#  prev_species_list::                    Display previous species list in index.
#  next_species_list::                    Display next species list in index.
#
#  make_report::                          Display contents of species list as report.
#
#  name_lister::                          Efficient javascripty way to build a list of names.
#  create_species_list::                  Create new list.
#  edit_species_list::                    Edit existing list.
#  upload_species_list::                  Same as edit_species_list but gets list from file.
#  destroy_species_list::                 Destroy list.
#  manage_species_lists::                 Add/remove an observation from a user's lists.
#  add_observation_to_species_list::      (post method)
#  remove_observation_from_species_list:: (post method)
#  bulk_editor::                          Bulk edit observations in species list.
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
  # require 'csv'
  # require 'rtf'

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
    :species_lists_for_project,
  ]

  before_filter :disable_link_prefetching, :except => [
    :create_species_list,
    :edit_species_list,
    :manage_species_lists,
    :show_species_list,
  ]

  before_filter :require_successful_user, :only => [
    :create_species_list, :name_lister
  ]
  ##############################################################################
  #
  #  :section: Index
  #
  ##############################################################################

  # Display list of selected species_lists, based on current Query.
  # (Linked from show_species_list, next to "prev" and "next".)
  def index_species_list # :nologin: :norobots:
    query = find_or_create_query(:SpeciesList, :by => params[:by])
    show_selected_species_lists(query, :id => params[:id].to_s,
                                :always_index => true)
  end

  # Display list of all species_lists, sorted by date.  (Linked from left panel.)
  def list_species_lists # :nologin:
    query = create_query(:SpeciesList, :all, :by => :date)
    show_selected_species_lists(query, :id => params[:id].to_s, :by => params[:by])
  end

  # Display list of user's species_lists, sorted by date.  (Linked from left panel.)
  def species_lists_by_user # :nologin: :norobots:
    if user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      query = create_query(:SpeciesList, :by_user, :user => user)
      show_selected_species_lists(query)
    end
  end

  # Display list of SpeciesList's attached to a given project.
  def species_lists_for_project
    if project = find_or_goto_index(Project, params[:id].to_s)
      query = create_query(:SpeciesList, :for_project, :project => project)
      show_selected_species_lists(query, {:always_index => 1})
    end
  end

  # Display list of all species_lists, sorted by title.  (Linked from left panel.)
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
      ['title',       :sort_by_title.t],
      ['date',        :sort_by_date.t],
      ['user',        :sort_by_user.t],
      ['created_at',  :sort_by_created_at.t],
      [(query.flavor == :by_rss_log ? 'rss_log' : 'updated_at'),
                      :sort_by_updated_at.t],
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
  #  :section: Show
  #
  ##############################################################################

  def show_species_list # :nologin: :prefetch:
    store_location
    clear_query_in_session
    pass_query_params
    if @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      @query = create_query(:Observation, :in_species_list, :by => :name,
                            :species_list => @species_list)
      store_query_in_session(@query) if !params[:set_source].blank?
      @query.need_letters = 'names.sort_name'
      @pages = paginate_letters(:letter, :page, 100)
      @objects = @query.paginate(@pages, :include => [:user, :name, :location, {:thumb_image => :image_votes}])
    end
  end

  def next_species_list # :nologin: :norobots:
    redirect_to_next_object(:next, SpeciesList, params[:id].to_s)
  end

  def prev_species_list # :nologin: :norobots:
    redirect_to_next_object(:prev, SpeciesList, params[:id].to_s)
  end

  def print_labels
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    render(:action => 'print_labels', :layout => 'printable')
  end

  ##############################################################################
  #
  #  :section: Reports
  #
  ##############################################################################

  # Used by show_species_list.
  def make_report # :nologin: :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      names = @species_list.names
      case params[:type]
      when 'txt'
        render_name_list_as_txt(names)
      when 'rtf'
        render_name_list_as_rtf(names)
      when 'csv'
        render_name_list_as_csv(names)
      else
        flash_error(:make_report_not_supported.t(:type => params[:type]))
        redirect_to(:action => "show_species_list", :id => params[:id].to_s)
      end
    end
  end

  def render_name_list_as_txt(names, charset=nil)
    charset ||= 'UTF-8'
    charset = charset.upcase
    if !['ASCII', 'ISO-8859-1', 'UTF-8'].include?(charset)
      raise "Unsupported text report charset: #{charset}"
    end
    str = names.map(&:real_search_name).join("\r\n")
    str = case charset
      when 'ASCII'; str.to_ascii
      when 'UTF-8'; "\xEF\xBB\xBF" + str
      else str.iconv(charset)
    end
    send_data(str,
      :type => 'text/plain',
      :charset => charset,
      :disposition => 'attachment',
      :filename => 'report.txt'
    )
  end

  def render_name_list_as_csv(names, charset=nil)
    charset ||= 'ISO-8859-1'
    charset = charset.upcase
    if !['ASCII', 'ISO-8859-1'].include?(charset)
      raise "Unsupported CSV report charset: #{charset}"
    end
    str = CSV.generate do |csv|
      csv << ['scientific_name', 'authority', 'citation', 'accepted']
      names.each do |name|
        csv << [name.real_text_name, name.author, name.citation,
          name.deprecated ? '' : '1'].map {|v| v.blank? ? nil : v}
      end
    end
    str = case charset
      when 'UTF-8'; str
      when 'ASCII'; str.to_ascii
      else
        str.force_encoding('UTF-8')
        str.iconv(charset)
    end
    send_data(str,
      :type => 'text/csv',
      :charset => charset,
      :header => 'present',
      :disposition => 'attachment',
      :filename => 'report.csv'
    )
  end

  def render_name_list_as_rtf(names)
    doc = RTF::Document.new(RTF::Font::SWISS)
    for name in names
      rank      = name.rank
      text_name = name.real_text_name
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
      :type => 'text/rtf',
      :charset => 'ISO-8859-1',
      :disposition => 'attachment',
      :filename => 'report.rtf'
    )
  end

  ################################################################################
  #
  #  :section: Create and Modify
  #
  ################################################################################

  # Specialized javascripty form for creating a list of names, at Darvin's request.
  # Links into create_species_list.
  def name_lister # :nologin: :norobots:
    # Names are passed in as string, one name per line.
    @name_strings = (params[:results] || '').chomp.split("\n").map {|n| n.to_s.chomp}
    if request.method == "POST"
      # (make this an instance var to give unit test access)
      @names = @name_strings.map do |str|
        str.sub!(/\*$/, '')
        name, author = str.split('|')
        name.gsub!('ë', 'e')
        if author
          Name.find_by_text_name_and_author(name, author)
        else
          Name.find_by_text_name(name)
        end
      end.select {|n| !n.nil?}
      case params[:commit]
      when :name_lister_submit_spl.l
        if @user
          @species_list = SpeciesList.new
          clear_query_in_session
          init_name_vars_for_create()
          init_member_vars_for_create()
          init_project_vars_for_create()
          @checklist ||= []
          @list_members = params[:results].gsub('|',' ').gsub('*','')
          render(:action => 'create_species_list')
        end
      when :name_lister_submit_txt.l
        render_name_list_as_txt(@names)
      when :name_lister_submit_rtf.l
        render_name_list_as_rtf(@names)
      when :name_lister_submit_csv.l
        render_name_list_as_csv(@names)
      else
        flash_error(:name_lister_bad_submit.t(:button => params[:commit]))
      end
    end
  end

  def create_species_list # :prefetch: :norobots:
    @species_list = SpeciesList.new
    if request.method != "POST"
      init_name_vars_for_create()
      init_member_vars_for_create()
      init_project_vars_for_create()
      if !params[:clone].blank?
        init_name_vars_for_clone(params[:clone])
      end
      @checklist ||= calc_checklist
    else
      process_species_list('created_at')
    end
  end

  def edit_species_list # :prefetch: :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      if !check_permission!(@species_list)
        redirect_to(:action => 'show_species_list', :id => @species_list)
      elsif request.method != "POST"
        init_name_vars_for_edit(@species_list)
        init_member_vars_for_edit(@species_list)
        init_project_vars_for_edit(@species_list)
        @checklist ||= calc_checklist
      else
        process_species_list('updated')
      end
    end
  end

  # Form to let user create/edit species_list from file.
  def upload_species_list # :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      if !check_permission!(@species_list)
        redirect_to(:action => 'show_species_list', :id => @species_list)
      elsif request.method != "POST"
        query = create_query(:Observation, :in_species_list, :by => :name,
                             :species_list => @species_list)
        @observation_list = query.results
      else
        sorter = NameSorter.new
        @species_list.file = params[:species_list][:file]
        @species_list.process_file_data(sorter)
        init_name_vars_from_sorter(@species_list, sorter)
        init_member_vars_for_edit(@species_list)
        init_project_vars_for_edit(@species_list)
        @checklist ||= calc_checklist
        render(:action => 'edit_species_list')
      end
    end
  end

  def destroy_species_list # :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      if check_permission!(@species_list)
        @species_list.destroy
        Transaction.delete_species_list(:id => @species_list)
        flash_notice(:runtime_species_list_destroy_success.t(:id => params[:id].to_s))
        redirect_to(:action => 'list_species_lists')
      else
        redirect_to(:action => 'show_species_list', :id => @species_list)
      end
    end
  end

  # Form to let user add/remove an observation from one of their species lists.
  def manage_species_lists # :prefetch: :norobots:
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    @all_lists = @user.all_editable_species_lists
  end

  # Used by manage_species_lists.
  def remove_observation_from_species_list # :norobots:
    if species_list = find_or_goto_index(SpeciesList, params[:species_list],
                                         :include => :observations)
      if observation = find_or_goto_index(Observation, params[:observation])
        if check_permission!(species_list)
          species_list.remove_observation(observation)
          flash_notice(:runtime_species_list_remove_observation_success.t(
            :name => species_list.unique_format_name, :id => observation.id))
          redirect_to(:action => 'manage_species_lists', :id => observation.id)
        else
          redirect_to(:action => 'show_species_list', :id => species_list.id)
        end
      end
    end
  end

  # Used by manage_species_lists.
  def add_observation_to_species_list # :norobots:
    if species_list = find_or_goto_index(SpeciesList, params[:species_list],
                                         :include => :observations)
      if observation = find_or_goto_index(Observation, params[:observation])
        if check_permission!(species_list)
          species_list.add_observation(observation)
          flash_notice(:runtime_species_list_add_observation_success.t(
            :name => species_list.unique_format_name, :id => observation.id))
          redirect_to(:action => 'manage_species_lists', :id => observation.id)
        end
      end
    end
  end

  # Bulk-edit observations (at least the ones editable by this user) in a (any) species list.
  def bulk_editor # :norobots:
    if @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
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
      @no_vote = Vote.new
      @no_vote.value = 0
      if @observation.empty?
        flash_error(:species_list_bulk_editor_you_own_no_observations.t)
        redirect_to(:action => 'show_species_list', :id => @species_list.id)
      elsif request.method == "POST"
        updates = 0
        stay_on_page = false
        for obs in @observations
          args = params[:observation][obs.id.to_s] || {} rescue {}
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

  # ----------------------------
  #  :section: Manage Projects
  # ----------------------------

  def manage_projects # :norobots:
    if @list = find_or_goto_index(SpeciesList, params[:id].to_s)
      if not check_permission!(@list)
        redirect_to(:action => 'show_species_list', :id => @list.id)
      else
        @projects = projects_to_manage
        @object_states = manage_object_states
        @project_states = manage_project_states
        if request.method == "POST"
          if params[:commit] == :ATTACH.l
            if attach_objects_to_projects
              redirect_to(:action => 'show_species_list', :id => @list.id)
            else
              flash_warning(:runtime_no_changes.t)
            end
          elsif params[:commit] == :REMOVE.l
            if remove_objects_from_projects
              redirect_to(:action => 'show_species_list', :id => @list.id)
            else
              flash_warning(:runtime_no_changes.t)
            end
          else
            flash_error("Invalid submit button: #{params[:commit].inspect}")
          end
        end
      end
    end
  end

  def projects_to_manage
    projects = @user.projects_member
    if @list.user == @user
      projects += @list.projects
      projects.uniq!
    end
    return projects
  end

  def manage_object_states
    {
      :list => !params[:objects_list].blank?,
      :obs  => !params[:objects_obs].blank?,
      :img  => !params[:objects_img].blank?,
    }
  end

  def manage_project_states
    states = {}
    for proj in @projects
      states[proj.id] = !params["projects_#{proj.id}"].blank?
    end
    return states
  end

  def attach_objects_to_projects
    @any_changes = false
    for proj in @projects
      if @project_states[proj.id]
        if not @user.projects_member.include?(proj)
          flash_error(:species_list_projects_no_add_to_project.t(:proj => proj.title))
        else
          attach_species_list_to_project(proj) if @object_states[:list]
          attach_observations_to_project(proj) if @object_states[:obs]
          attach_images_to_project(proj)       if @object_states[:img]
        end
      end
    end
    return @any_changes
  end

  def remove_objects_from_projects
    @any_changes = false
    for proj in @projects
      if @project_states[proj.id]
        remove_species_list_from_project(proj) if @object_states[:list]
        remove_observations_from_project(proj) if @object_states[:obs]
        remove_images_from_project(proj)       if @object_states[:img]
      end
    end
    return @any_changes
  end

  def attach_species_list_to_project(proj)
    if not @list.projects.include?(proj)
      proj.add_species_list(@list)
      flash_notice(:attached_to_project.t(:object => :species_list, :project => proj.title))
      @any_changes = true
    end
  end

  def remove_species_list_from_project(proj)
    if @list.projects.include?(proj)
      proj.remove_species_list(@list)
      flash_notice(:removed_from_project.t(:object => :species_list, :project => proj.title))
      @any_changes = true
    end
  end

  def attach_observations_to_project(proj)
    obs = @list.observations.select {|o| check_permission(o)}
    obs -= proj.observations
    if obs.any?
      proj.add_observations(obs)
      flash_notice(:attached_to_project.t(:object => "#{obs.length} #{:observations.l}",
                                         :project => proj.title))
      @any_changes = true
    end
  end

  def remove_observations_from_project(proj)
    obs = @list.observations.select {|o| check_permission(o)}
    if not @user.projects_member.include?(proj)
      obs.select! {|o| o.user == @user}
    end
    obs &= proj.observations
    if obs.any?
      proj.remove_observations(obs)
      flash_notice(:removed_from_project.t(:object => "#{obs.length} #{:observations.l}",
                                          :project => proj.title))
      @any_changes = true
    end
  end

  def attach_images_to_project(proj)
    imgs = @list.observations.map(&:images).flatten.uniq.select {|i| check_permission(i)}
    imgs -= proj.images
    if imgs.any?
      proj.add_images(imgs)
      flash_notice(:attached_to_project.t(:object => "#{imgs.length} #{:images.l}",
                                         :project => proj.title))
      @any_changes = true
    end
  end

  def remove_images_from_project(proj)
    imgs = @list.observations.map(&:images).flatten.uniq.select {|i| check_permission(i)}
    if not @user.projects_member.include?(proj)
      imgs.select! {|i| i.user == @user}
    end
    imgs &= proj.observations
    if imgs.any?
      proj.remove_images(imgs)
      flash_notice(:removed_from_project.t(:object => "#{imgs.length} #{:images.l}",
                                          :project => proj.title))
      @any_changes = true
    end
  end

  ################################################################################
  #
  #  :section: Helpers
  #
  ################################################################################

  # Validate list of names, and if successful, create observations.
  # Parameters involved in name list validation:
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
  def process_species_list(created_or_updated)
    redirected = false
    args = params[:species_list]

    # Update the timestamps/user/when/where/title/notes fields.
    now = Time.now
    @species_list.created_at = now if created_or_updated == :created_at
    @species_list.updated_at = now
    @species_list.user = @user
    @species_list.attributes = args
    @species_list.title = @species_list.title.to_s.strip_squeeze
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

    # Make sure all the names (that have been approved) exist.
    list = params[:list][:members].gsub('_', ' ').strip_squeeze rescue ''
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
    # (construct_observations) create the observations.  This always succeeds,
    # so we can redirect to show_species_list (or chain to create_location).
    if !failed and @dubious_where_reasons == []
      if !@species_list.save
        flash_object_errors(@species_list)
      else
        if created_or_updated == :created_at
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

        @species_list.log("log_species_list_#{created_or_updated}".to_sym)
        if created_or_updated == :created_at
          flash_notice(:runtime_species_list_create_success.t(:id => @species_list.id))
        else
          flash_notice(:runtime_species_list_edit_success.t(:id => @species_list.id))
        end

        update_projects(@species_list, params[:project])
        construct_observations(@species_list, sorter, created_or_updated)

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
      init_name_vars_from_sorter(@species_list, sorter)
      init_member_vars_for_reload()
      init_project_vars_for_reload(@species_list)
    end
  end

  # Creates observations for names written in and/or selected from checklist.
  # Uses the member instance vars, as well as:
  #   params[:chosen_approved_names]    Names from radio boxes.
  #   params[:checklist_data]           Names from LHS check boxes.
  def construct_observations(spl, sorter, created_or_updated)

    # Put together a list of arguments to use when creating new observations.
    member_args = params[:member] || {}
    sp_args = {
      :created_at => spl.updated_at,
      :updated_at => spl.updated_at,
      :user     => @user,
      :projects => spl.projects,
      :location => spl.location,
      :where    => spl.where,
      :vote     => member_args[:vote],
      :notes    => member_args[:notes].to_s,
      :lat      => member_args[:lat].to_s,
      :long     => member_args[:long].to_s,
      :alt      => member_args[:alt].to_s,
      :is_collection_location => (member_args[:is_collection_location] == '1'),
      :specimen => (member_args[:specimen] == '1'),
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
      spl.construct_observation(name, sp_args)
    end

    # Add checked names from LHS check boxes.  It doesn't check if they are
    # already in there; it creates new observations for each and stuffs it in.
    sp_args[:when] = spl.when
    if params[:checklist_data]
      for key, value in params[:checklist_data]
        if value == "1"
          name = find_chosen_name(key.to_i, params[:chosen_approved_names])
          spl.construct_observation(name, sp_args)
        end
      end
    end
  end

  def find_chosen_name(id, alternatives)
    if alternatives and
       (alt_id = alternatives[id.to_s])
      Name.find(alt_id)
    else
      Name.find(id)
    end
  end

  # Called by the actions which use create/edit_species_list form.  It grabs a
  # list of names to list with checkboxes in the left-hand column of the form.
  # By default it looks up a query stored in the session (you can, for example,
  # "save" another species list "for later" for this purpose).  The result is
  # an Array of names where the values are [display_name, name_id].  This
  # is destined for the instance variable @checklist.
  def calc_checklist(query=nil)
    results = []
    if query or (query = get_query_from_session)
      case query.model_symbol
      when :Name
        results = query.select_rows(
          :select => 'DISTINCT names.display_name, names.id',
          :limit  => 1000
        )
      when :Observation
        results = query.select_rows(
          :select => 'DISTINCT names.display_name, names.id',
          :join   => :names,
          :limit  => 1000
        )
      when :Image
        results = query.select_rows(
          :select => 'DISTINCT names.display_name, names.id',
          :join   => {:images_observations => {:observations => :names}},
          :limit  => 1000
        )
      when :Location
        results = query.select_rows(
          :select => 'DISTINCT names.display_name, names.id',
          :join   => {:observations => :names},
          :limit  => 1000
        )
      when :RssLog
        results = query.select_rows(
          :select => 'DISTINCT names.display_name, names.id',
          :join   => {:observations => :names},
          :where  => 'rss_logs.observation_id > 0',
          :limit  => 1000
        )
      else
        results = []
      end
    end
    return results
  end

  def init_name_vars_for_create()
    @checklist_names = {}
    @new_names = []
    @multiple_names = []
    @deprecated_names = []
    @list_members = nil
    @checklist = nil
    @place_name = nil
  end

  def init_name_vars_for_edit(spl)
    init_name_vars_for_create()
    @deprecated_names = spl.names.select(&:deprecated)
    @place_name = spl.place_name
  end

  def init_name_vars_for_clone(clone_id)
    if clone = SpeciesList.safe_find(clone_id)
      query = create_query(:Observation, :in_species_list, :species_list => clone)
      @checklist = calc_checklist(query)
      @species_list.when = clone.when
      @species_list.place_name = clone.place_name
      @species_list.location = clone.location
      @species_list.title = clone.title
    end
  end

  def init_name_vars_from_sorter(spl, sorter)
    @checklist_names  = params[:checklist_data] || {}
    @new_names = sorter.new_name_strs.uniq.sort
    @multiple_names = sorter.multiple_names.uniq.sort_by(&:search_name)
    @deprecated_names = sorter.deprecated_names.uniq.sort_by(&:search_name)
    @list_members = sorter.all_line_strs.join("\r\n")
    @checklist = nil
    @place_name = spl.place_name
  end

  def init_member_vars_for_create()
    @member_vote = Vote.maximum_vote
    @member_notes = nil
    @member_lat = nil
    @member_long = nil
    @member_alt = nil
    @member_is_collection_location = true
    @member_specimen = false
  end

  def init_member_vars_for_edit(spl)
    if obs = @species_list.observations.last
      @member_vote = obs.namings.first.users_vote(@user).value rescue Vote.maximum_vote
      @member_notes = obs.notes
      @member_lat = obs.lat
      @member_long = obs.long
      @member_alt = obs.alt
      @member_is_collection_location = obs.is_collection_location
      @member_specimen = obs.specimen
    else
      init_member_vars_for_create()
    end
  end

  def init_member_vars_for_reload()
    @member_vote = params[:member][:vote].to_s rescue ''
    @member_notes = params[:member][:notes].to_s rescue ''
    @member_lat = params[:member][:lat].to_s rescue ''
    @member_long = params[:member][:long].to_s rescue ''
    @member_alt = params[:member][:alt].to_s rescue ''
    @member_is_collection_location = params[:member][:is_collection_location] == '1' rescue true
    @member_specimen = params[:member][:specimen] == '1' rescue false
  end

  def init_project_vars
    @projects = User.current.projects_member.sort_by(&:title)
    @project_checks = {}
  end

  def init_project_vars_for_create
    init_project_vars
    last_obs = Observation.find_by_user_id(User.current_id, :order => 'created_at DESC')
    if last_obs && last_obs.created_at > 1.hour.ago
      for proj in last_obs.projects
        @project_checks[proj.id] = true
      end
    end
  end

  def init_project_vars_for_edit(spl)
    init_project_vars
    for proj in spl.projects
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_project_vars_for_reload(spl)
    init_project_vars
    for proj in spl.projects
      @projects << proj unless @projects.include?(proj)
    end
    for proj in @projects
      @project_checks[proj.id] = params[:project]["id_#{proj.id}"] == '1' rescue false
    end
  end

  def update_projects(spl, checks)
    if checks
      any_changes = false
      for project in User.current.projects_member
        before = spl.projects.include?(project)
        after = checks["id_#{project.id}"] == '1'
        if before != after
          if after
            project.add_species_list(spl)
            flash_notice(:attached_to_project.t(:object => :species_list, :project => project.title))
            any_changes = true
          else
            project.remove_species_list(spl)
            flash_notice(:removed_from_project.t(:object => :species_list, :project => project.title))
            any_changes = true
          end
        end
      end
      if any_changes
        flash_notice(:species_list_show_manage_observations_too.t)
      end
    end
  end
end
