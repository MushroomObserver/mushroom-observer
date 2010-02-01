#
#  Views: ("*" - login required)
#     list_species_lists                     List of lists by date.
#     species_lists_by_title                 List of lists by title.
#     species_lists_by_user                  List of lists created by user.
#     show_species_list                      Display notes/etc. and list of species.
#     make_report                            Display contents of species list as report.
#   * create_species_list                    Create new list.
#   * name_lister                            Efficient javascripty way to build a list of names.
#   * edit_species_list                      Edit existing list.
#   * upload_species_list                    Same as edit_species_list but gets list from file.
#   * destroy_species_list                   Destroy list.
#   * manage_species_lists                   Add/remove an observation from a user's lists.
#   * add_observation_to_species_list        (post method)
#   * remove_observation_from_species_list   (post method)
#
#  Helpers:
#    calc_checklist(query)                Get list of names for LHS of _species_list_form.
#    get_list_of_deprecated_names(spl)    Get list of names from list that are deprecated.
#    process_species_list(...)            Create/update species list using form data.
#    construct_observations(...)          Create observations for new names added to list.
#    find_chosen_name(id, alternatives)   (helper)
#    render_name_list_as_txt(names)       Display list as text file.
#    render_name_list_as_rtf(names)       Display list as richtext file.
#    render_name_list_as_csv(names)       Display list as csv spreadsheet.
#
#  NOTE: There is some ambiguity between observations and names that makes this
#  slightly confusing.  The end result of a species list is actually a list of
#  *observations*, not species.  However, creation and editing is generally
#  accomplished via names alone (although see manage_species_lists for the one
#  exception).  In the end all these names cause rudimentary observations to
#  spring into existence.
#
################################################################################

class SpeciesListController < ApplicationController
  require 'rtf'

  before_filter :login_required, :except => [
    :list_species_lists,
    :make_report,
    :name_lister,
    :show_species_list,
    :species_lists_by_title,
    :species_lists_by_user,
  ]

  before_filter :disable_link_prefetching, :except => [
    :create_species_list,
    :edit_species_list,
    :manage_species_lists,
    :show_species_list,
  ]

  # Display list of all species_lists, sorted by date.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs: @species_lists, @species_list_pages
  def list_species_lists
    store_location
    store_query
    query = find_or_create_query(:SpeciesList, :all, :by => :date)
    @pages = paginate_numbers(:page, 10)
    @objects = query.paginate(@pages)
  end

  # Display list of user's species_lists, sorted by date.
  # Linked from: left-hand panel
  # Inputs: params[:id] (user)
  # Outputs: @title, @species_lists, @species_list_pages
  def species_lists_by_user
    user = User.find(params[:id])
    store_location
    store_query
    @title = :species_list_list_by_user.l(:user => user.legal_name)
    query = create_query(:SpeciesList, :by_user, :user => user)
    @pages = paginate_numbers(:page, 10)
    @objects = query.paginate(@pages)
    render(:action => "list_species_lists")
  end

  # Display list of all species_lists, sorted by title.
  # Linked from: left-hand panel
  # Inputs: none
  # Outputs: @species_lists
  def species_lists_by_title
    store_location
    store_query
    query = create_query(:SpeciesList, :all, :by => :title)
    @pages = paginate_numbers(:page, 100)
    @objects = query.paginate(@pages)
  end

  # Linked from: list_species_lists, show_observation, create/edit_species_list, etc. etc.
  # Inputs: params[:id] (species_list)
  # Outputs: @species_list, @observation_list
  # Use session to store the current species list since this parallels
  # the usage for show_observation.
  def show_species_list
    store_location
    store_query
    @species_list = SpeciesList.find(params[:id])
    query = create_query(:Observation, :in_species_list, :by => :name,
                         :species_list => @species_list)
    store_query(query) if params[:set_source].to_s != ''
    @pages = paginate_letters(:letter, :page, 100)
    @objects = query.paginate(@pages, 'names.text_name')
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
  #   session[:checklist_source]
  def create_species_list
    @species_list = SpeciesList.new
    if request.method != :post
      @checklist_names  = {}
      @list_members     = nil
      @new_names        = nil
      @multiple_names   = nil
      @deprecated_names = nil
      @member_notes     = nil
      if (params[:clone].to_s != '') and
         (clone = SpeciesList.safe_find(params[:clone]))
        query = create_query(:Observation, :in_species_list,
                             :species_list => clone)
        @checklist = calc_checklist(query)
        @species_list.when  = clone.when
        @species_list.where = clone.where
        @species_list.title = clone.title
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
  #   session[:checklist_source]
  def edit_species_list
    @species_list = SpeciesList.find(params[:id])
    if !check_permission!(@species_list.user_id)
      redirect_to(:action => 'show_species_list', :id => @species_list)
    elsif request.method != :post
      @checklist_names  = {}
      @list_members     = nil
      @new_names        = nil
      @multiple_names   = nil
      @member_notes     = nil
      @deprecated_names = get_list_of_deprecated_names(@species_list)
      @checklist        = calc_checklist
    else
      process_species_list('updated')
    end
  end

  # Form to let user create/edit species_list from file.
  # Linked from: edit_species_list
  # Inputs: params[:id] (species_list)
  #   params[:species_list][:file]
  # Get: @species_list
  # Post: goes to edit_species_list
  def upload_species_list
    @species_list = SpeciesList.find(params[:id])
    if !check_permission!(@species_list.user_id)
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
      @multiple_names   = sorter.multiple_line_strs.uniq.sort
      @deprecated_names = sorter.deprecated_name_strs.uniq.sort
      @checklist_names  = {}
      @member_notes     = ''
      render(:action => 'edit_species_list')
    end
  end

  # Callback to destroy a list.
  # Linked from: show_species_list
  # Inputs: params[:id] (species_list)
  # Redirects to list_species_lists.
  def destroy_species_list
    @species_list = SpeciesList.find(params[:id])
    if check_permission!(@species_list.user_id)
      @species_list.destroy
      Transaction.delete_species_list(:id => @species_list)
      flash_notice(:species_list_destroy_success.t)
      redirect_to(:action => 'list_species_lists')
    else
      redirect_to(:action => 'show_species_list', :id => @species_list)
    end
  end

  # Form to let user add/remove an observation from his various lists.
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Outputs: @observation
  def manage_species_lists
    @observation = Observation.find(params[:id])
    @all_lists = SpeciesList.find(:all,
      :conditions => ['user_id = ?', @user.id],
      :order => "'modified' desc"
    )
  end

  # Remove an observation from a species_list.
  # Linked from: manage_species_lists
  # Inputs:
  #   params[:species_list]
  #   params[:observation]
  # Redirects back to manage_species_lists.
  def remove_observation_from_species_list
    species_list = SpeciesList.find(params[:species_list])
    if check_permission!(species_list.user_id)
      observation = Observation.find(params[:observation])
      if species_list.observations.include?(observation)
        species_list.observations.delete(observation)
        Transaction.put_species_list(
          :id              => species_list,
          :del_observation => observation
        )
      end
      flash_notice(:species_list_remove_observation_success.t(:name => species_list.unique_format_name))
      redirect_to(:action => 'manage_species_lists', :id => observation.id)
    else
      redirect_to(:action => 'show_species_list', :id => species_list.id)
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
    if check_permission!(species_list.user_id)
      observation = Observation.find(params[:observation])
      if !species_list.observations.include?(observation)
        species_list.observations << observation
        Transaction.put_species_list(
          :id              => species_list,
          :add_observation => observation
        )
      end
      flash_notice(:species_list_add_observation_success.t(:name => species_list.unique_format_name))
      redirect_to(:action => 'manage_species_lists', :id => observation.id)
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
  def name_lister
    @genera = Name.connection.select_all %(
      SELECT text_name as n, deprecated as d
      FROM names
      WHERE rank = 'Genus' AND correct_spelling_id IS NULL
      ORDER BY text_name
    )

    @species = Name.connection.select_all %(
      SELECT text_name as n, author as a, deprecated as d, synonym_id as s
      FROM names
      WHERE (rank = 'Species' OR rank = 'Subspecies' OR rank = 'Variety' OR rank = 'Form')
            AND correct_spelling_id IS NULL
      ORDER BY text_name
    )

    # Place "*" after all accepted genera.
    @genera = @genera.map do |rec|
      n, d = rec.values_at('n', 'd')
      d.to_i == 1 ? n : n + '*'
    end

    # How many times is each name used?
    occurs = {}
    for rec in @species
      n = rec['n']
      occurs[n] ||= 0
      occurs[n] += 1
    end

    # Build map from synonym_id to list of valid names.
    valid = {}
    for rec in @species
      n, a, d, s = rec.values_at('n', 'a', 'd', 's')
      need_author = occurs[n] > 1
      n += '|' + a if a.to_s != '' && need_author
      if s.to_i > 0 && d.to_i != 1
        l = valid[s] ||= []
        l.push(n) if !l.include?(n)
      end
    end

    # Now insert valid synonyms after each deprecated name.  Stick a "*" after
    # all accepted names (including, of course, the accepted synonyms).
    # Include author after names, using a "|" to help make it easy for
    # javascript to parse it correctly.
    @species = @species.map do |rec|
      n, a, d, s = rec.values_at('n', 'a', 'd', 's')
      need_author = occurs[n] > 1
      n += '|' + a if a.to_s != '' && need_author
      n += '*' if d.to_i != 1
      d.to_i == 1 && valid[s] ? ([n] + valid[s].map {|x| "= #{x}"}) : n
    end.flatten

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
        @new_names        = nil
        @multiple_names   = nil
        @deprecated_names = nil
        @member_notes     = nil
        store_query
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
  def make_report
    id = params[:id].to_i
    spl = SpeciesList.find(id)
    names = spl ? spl.names : []
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
      if true && name.author.to_s != ''
        name.text_name + ' ' + name.author
      else
        name.text_name
      end
    end.join("\r\n")
    str = case charset
      when 'ASCII': str.to_ascii
      when 'UTF-8': "\xEF\xBB\xBF" + str
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
          name.deprecated ? '' : '1'].map {|v| v == '' ? nil : v}
      end
    end
    str = case charset
      when 'UTF-8': str
      when 'ASCII': str.to_ascii
      else str.iconv(charset)
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
      doc << " " + author if author && author != ""
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
  #   params[:member][:notes]
  #   params[:list][:members]               String that user typed in in big text area on right side (squozen and stripped).
  #   params[:approved_names]               List of new names from prev post.
  #   params[:approved_deprecated_names]    List of deprecated names from prev post.
  #   params[:chosen_names][name]           Radio boxes disambiguating multiple names
  #   params[:chosen_approved_names][name]  Radio boxes allowing user to choose preferred names for deprecated ones.
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

    # This just makes sure all the names (that have been approved) exist.
    list = params[:list][:members].gsub('_', ' ').strip_squeeze
    construct_approved_names(list, params[:approved_names])

    # Sets up a NameSorter object.  Does NOT affect species_list.
    sorter = setup_sorter(params, @species_list, list)

    # Now let's see all the ways in which NameSorter can fail...
    # Does list have "Name one = Name two" type lines?
    if sorter.has_new_synonyms
      flash_error(:species_list_need_to_use_bulk.t)
      sorter.reset_new_names
    # Are there any unrecognized names?
    elsif sorter.new_name_strs != []
      flash_error "Unrecognized names given: '#{sorter.new_name_strs.map(&:to_s).join("', '")}'" if TESTING
    # Are there any ambiguous names?
    elsif !sorter.only_single_names
      flash_error "Ambiguous names given: '#{sorter.multiple_line_strs.map(&:to_s).join("', '")}'" if TESTING
    # Are there and deprecated names that haven't been approved?
    elsif sorter.has_unapproved_deprecated_names
      flash_error("Found deprecated names.") if TESTING

    # Okay, at this point we've apparently validated the new list of names.
    # Save the OTHER changes to the species list, then let this other method
    # (construct_observations) update the members.  This always succeeds, so
    # we can redirect to show_species_list.
    else
      if !@species_list.save
        flash_object_errors(@species_list)
      else
        if type_str == 'created'
          Transaction.post_species_list(
            :id       => @species_list,
            :date     => @species_list.when,
            :location => @species_list.where,
            :title    => @species_list.title,
            :notes    => @species_list.notes
          )
        else
          args = {}
          args[:date]     = @species_list.when  if @species_list.when_changed?
          args[:location] = @species_list.where if @species_list.where_changed?
          args[:title]    = @species_list.title if @species_list.title_changed?
          args[:notes]    = @species_list.notes if @species_list.notes_changed?
          if !args.empty?
            args[:id] = @species_list
            Transaction.put_species_list(args)
          end
        end

        construct_observations(@species_list, params, type_str, @user, sorter)

        if has_unshown_notifications?(@user, :naming)
          redirect_to(:controller => 'observer', :action => 'show_notifications')
        else
          redirect_to(:action => 'show_species_list', :id => @species_list)
        end
        redirected = true
      end
    end

    # Failed to create due to synonyms, unrecognized names, etc.
    if !redirected
      @list_members     = sorter.all_line_strs.join("\r\n")
      @new_names        = sorter.new_name_strs.uniq.sort # --> "approved_names"
      @multiple_names   = sorter.multiple_line_strs.uniq.sort
      @deprecated_names = sorter.deprecated_name_strs.uniq.sort
      @checklist_names  = params[:checklist_data] || {}
      @member_notes     = params[:member] ? params[:member][:notes] : ""
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
    if query or
       (query_id = session[:checklist_source]) and
       (query = Query.safe_find(query_id))
      @checklist = case query.model_symbol

      when :Name
        query.select_rows(
          :select => 'DISTINCT names.observation_name, names.id',
          :limit  => 1000
        )

      when :Observation
        query.select_rows(
          :select  => 'DISTINCT names.observation_name, names.id',
          :include => :names,
          :limit   => 1000
        )

      when :Image
        query.select_rows(
          :select  => 'DISTINCT names.observation_name, names.id',
          :include => {:images_observations => {:observations => :names}},
          :limit   => 1000
        )

      when :Location
        query.select_rows(
          :select  => 'DISTINCT names.observation_name, names.id',
          :include => {:observations => :names},
          :limit   => 1000
        )

      when :RssLog
        query.select_rows(
          :select  => 'DISTINCT names.observation_name, names.id',
          :include => {:observations => :names},
          :where   => 'rss_logs.observation_id > 0',
          :limit   => 1000
        )

      else []
      end
    end
  end

  # Get list of names from species_list that are deprecated.
  def get_list_of_deprecated_names(spl)
    result = nil
    for obs in spl.observations
      name = obs.name
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
  def construct_observations(spl, params, type_str, user, sorter)
    spl.log("log_species_list_#{type_str}".to_sym)
    if type_str == 'created'
      flash_notice(:species_list_create_success.t)
    else
      flash_notice(:species_list_edit_success.t)
    end

    # Put together a list of arguments to use when creating new observations.
    sp_args = {
      :created  => spl.modified,
      :modified => spl.modified,
      :user     => user,
      :where    => spl.where,
      :specimen => 0,
      :notes    => params[:member][:notes]
    }

    # This updates certain observation namings already in the list.  It looks
    # for namings that are deprecated, then replaces them with approved
    # synonyms which the user has chosen via radio boxes in
    # params[:chosen_approved_names].
    if chosen_names = params[:chosen_approved_names]
      for observation in spl.observations
        for naming in observation.namings
          # (compensate for gsub in _form_species_lists)
          munged_name = naming.name.search_name.gsub(/\W/, "_")
          if alt_name_id = chosen_names[munged_name]
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

    # Add all "single names" from text list into species_list.  Creates a new
    # observation for each name.  What are "single names", incidentally??
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
