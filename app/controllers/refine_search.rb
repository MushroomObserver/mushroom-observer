#
#  = Refine Search
#
#  Controller mix-in used by ObserverController for observer/refine_search.
#
################################################################################

module RefineSearch

  # ranks      = Name.all_ranks.reverse.map {|r| ["rank_#{r}".upcase.to_sym, r]}
  # quality    = Image.all_votes.reverse.map {|v| [:"image_vote_short_#{v}", v]}
  # confidence = Vote.confidence_menu
  # licenses   = License.current_names_and_ids.map {|l,v| [l.sub(/Creative Commons/,'CC'), v]}

  ##############################################################################
  #
  #  :section: Field declarations
  #
  ##############################################################################

  class Field
    attr_accessor :id         # Our id for it (Symbol).
    attr_accessor :name       # Parameter name (Symbol).
    attr_accessor :label      # Label of form field (Symbol).
    attr_accessor :help       # Help text, if any (Symbol).
    attr_accessor :input      # Input type: :text, :text2, :menu, :menu2
    attr_accessor :autocomplete # Autocompleter: :name, :user, etc.
    attr_accessor :tokens     # Allow multiple values (OR) in autocompletion?
    attr_accessor :primer     # Prime auto-completer with Array of String's.
    attr_accessor :opts       # Menu options: [ [label, val], ... ]
    attr_accessor :default    # Default value (if non-blank).
    attr_accessor :blank      # Include blank in menu?
    attr_accessor :format     # Formatter: method name or Proc. (if != :parse)
    attr_accessor :parse      # Parser: method name or Proc.
    attr_accessor :declare    # Original declaration from Query.
    attr_accessor :required   # Is this a required parameter?

    def initialize(args={})
      for key, val in args
        send("#{key}=", val)
      end
    end

    def dup
      args = {}
      instance_variables.each do |x|
        args[x[1..-1]] = instance_variable_get(x)
      end
      Field.new(args)
    end
  end

  # ----------------------------
  #  Order of fields in form.
  # ----------------------------

  FIELD_ORDER = {

    :Comment => [
      :pattern,
      :user,
      :created,
      :modified,
      :users,
    ],

    :Image => [
      :pattern,
      :advanced_search_user,
      :advanced_search_name,
      :advanced_search_location,
      :advanced_search_content,
      :user,
      :name,
      :location,
      :location_where,
      :species_list,
      :observation,
      :nonconsensus,
      :synonyms,
      :created,
      :modified,
      :date,
      :users,
    ],

    :Location => [
      :pattern,
      :advanced_search_user,
      :advanced_search_name,
      :advanced_search_location,
      :advanced_search_content,
      :user,
      :name,
      :location,
      :location_where,
      :species_list,
      :observation,
      :nonconsensus,
      :synonyms,
      :created,
      :modified,
      :users,
    ],

    :LocationDescription => [
      :user,
      :created,
      :modified,
      :users,
    ],

    :Name => [
      :pattern,
      :advanced_search_user,
      :advanced_search_name,
      :advanced_search_location,
      :advanced_search_content,
      :user,
      :name,
      :location,
      :location_where,
      :species_list,
      :observation,
      :all_children,
      :deprecated,
      :misspellings,
      :created,
      :modified,
      :users,
    ],

    :NameDescription => [
      :user,
      :created,
      :modified,
      :users,
    ],

    :Observation => [
      :pattern,
      :advanced_search_user,
      :advanced_search_name,
      :advanced_search_location,
      :advanced_search_content,
      :user,
      :name,
      :location,
      :location_where,
      :species_list,
      :observation,
      :synonyms,
      :nonconsensus,
      :all_children,
      :created,
      :modified,
      :date,
      :users,
    ],

    :Project => [
      :pattern,
      :created,
      :modified,
      :users,
    ],

    :RssLog => [
      :rss_type,
      :modified,
    ],

    :SpeciesList => [
      :pattern,
      :user,
      :location,
      :location_where,
      :created,
      :modified,
      :date,
      :users,
    ],

    :User => [
      :pattern,
      :created,
      :modified,
    ],
  }

  # --------------------------------------
  #  Flavor- and model-specific aliases.
  # --------------------------------------

  FLAVOR_FIELDS = {
    :advanced_search => {
      :user     => :advanced_search_user,
      :name     => :advanced_search_name,
      :location => :advanced_search_location,
      :content  => :advanced_search_content,
    },
    :at_where    => { :location => :location_where },
    :of_children => { :all => :all_children },
    :with_observations_of_children => { :all => :all_children },
  }

  MODEL_FIELDS = {
    :RssLog => {
      :modified => :rss_modified,
      :type     => :rss_type,
    },
  }

  # ----------------------------
  #  Field specifications.
  # ----------------------------

  FIELDS = [

    # Advanced search fields.
    Field.new(
      :id    => :advanced_search_content,
      :name  => :content,
      :label => :refine_search_advanced_search_content,
      :input => :text
    ),
    Field.new(
      :id    => :advanced_search_location,
      :name  => :location,
      :label => :refine_search_advanced_search_location,
      :input => :text,
      :autocomplete => :location,
      :tokens => true
    ),
    Field.new(
      :id    => :advanced_search_name,
      :name  => :name,
      :label => :refine_search_advanced_search_name,
      :input => :text,
      :autocomplete => :name,
      :tokens => true
    ),
    Field.new(
      :id    => :advanced_search_user,
      :name  => :user,
      :label => :refine_search_advanced_search_user,
      :input => :text,
      :autocomplete => :user,
      :tokens => true
    ),

    # Include all children or only immediate children?
    Field.new(
      :id    => :all_children,
      :name  => :all,
      :label => :refine_search_all_children,
      :input => :menu,
      :opts  => [
        [:refine_search_all_children_true, 'true'],
        [:refine_search_all_children_false, 'false'],
      ],
      :default => false,
      :blank => false,
      :parse => :boolean
    ),

    # Specify time or range of times for time created.
    Field.new(
      :id     => :created,
      :name   => :created,
      :label  => :refine_search_created,
      :help   => :refine_search_times_help,
      :input  => :text2,
      :parse  => :times
    ),

    # Specify a date, range of dates, month or range of months.
    Field.new(
      :id     => :date,
      :name   => :date,
      :label  => :refine_search_date,
      :help   => :refine_search_dates_help,
      :input  => :text2,
      :parse  => :dates
    ),

    # Include deprecated names?
    Field.new(
      :id    => :deprecated,
      :name  => :deprecated,
      :label => :refine_search_deprecated,
      :input => :menu,
      :opts  => [
        [:refine_search_deprecated_no, 'no'],
        [:refine_search_deprecated_only, 'only'],
        [:refine_search_deprecated_either, 'either'],
      ],
      :default => :either,
      :blank => false
    ),

    # Specify a given (defined) location.
    Field.new(
      :id    => :location,
      :name  => :location,
      :label => :refine_search_location,
      :help  => :refine_search_location_help,
      :input => :text,
      :autocomplete => :location,
      :parse => :location
    ),

    # Specify a given (undefined) location.
    Field.new(
      :id    => :location_where,
      :name  => :location,
      :label => :refine_search_location_where,
      :help  => :refine_search_location_where_help,
      :input => :text,
      :autocomplete => :location
    ),

    # Include misspelt names?
    Field.new(
      :id    => :misspellings,
      :name  => :misspellings,
      :label => :refine_search_misspellings,
      :input => :menu,
      :opts  => [
        [:refine_search_misspellings_no, 'no'],
        [:refine_search_misspellings_only, 'only'],
        [:refine_search_misspellings_either, 'either'],
      ],
      :default => :no,
      :blank => false
    ),

    # Specify time or range of times for last modified.
    Field.new(
      :id     => :modified,
      :name   => :modified,
      :label  => :refine_search_modified,
      :help   => :refine_search_times_help,
      :input  => :text2,
      :parse  => :times
    ),

    # Specify time or range of times for RSS activity.
    Field.new(
      :id     => :rss_modified,
      :name   => :rss_modified,
      :label  => :refine_search_rss_modified,
      :help   => :refine_search_times_help,
      :input  => :text2,
      :parse  => :times
    ),

    # Specify a given name.
    Field.new(
      :id    => :name,
      :name  => :name,
      :label => :Name,
      :input => :text,
      :autocomplete => :name,
      :parse => :name
    ),

    # Include observations whose nonconsensus names match a given name?
    Field.new(
      :id    => :nonconsensus,
      :name  => :nonconsensus,
      :label => :refine_search_nonconsensus,
      :input => :menu,
      :opts  => [
        [:refine_search_nonconsensus_no, 'no'],
        [:refine_search_nonconsensus_all, 'all'],
        [:refine_search_nonconsensus_exclusive, 'exclusive'],
      ],
      :default => :no,
      :blank => false
    ),

    # Specify a given observation.
    Field.new(
      :id    => :observation,
      :name  => :observation,
      :label => :Observation,
      :input => :text,
      :parse => :observation
    ),

    # Search string for pattern search.
    Field.new(
      :id    => :pattern,
      :name  => :pattern,
      :label => :refine_search_pattern_search,
      :input => :text
    ),

    # Include observations whose nonconsensus names match a given name?
    Field.new(
      :id    => :rss_type,
      :name  => :type,
      :label => :refine_search_rss_log_type,
      :input => :text,
      :autocomplete => :menu,
      :tokens => true,
      :primer => [:all.t] + RssLog.all_types.map(&:to_sym).map(&:l),
      :parse => :rss_type,
      :default => 'all'
    ),

    # Specify a given species list.
    Field.new(
      :id    => :species_list,
      :name  => :species_list,
      :label => :Species_list,
      :input => :text,
      :autocomplete => :species_list,
      :parse => :species_list
    ),

    # Include observations of synonyms of a given name?
    Field.new(
      :id    => :synonyms,
      :name  => :synonyms,
      :label => :refine_search_synonyms,
      :input => :menu,
      :opts  => [
        [:refine_search_synonyms_no, 'no'],
        [:refine_search_synonyms_all, 'all'],
        [:refine_search_synonyms_exclusive, 'exclusive'],
      ],
      :default => :no,
      :blank => false
    ),

    # Specify a given user.
    Field.new(
      :id    => :user,
      :name  => :user,
      :label => :User,
      :input => :text,
      :autocomplete => :user,
      :parse => :user
    ),

    # Specify one or more users.
    Field.new(
      :id     => :users,
      :name   => :users,
      :label  => :refine_search_users,
      :help   => :refine_search_users_help,
      :input  => :text,
      :autocomplete => :user,
      :tokens => true,
      :parse  => :users
    ),
  ]

  ##############################################################################
  #
  #  :section: Formaters and Parsers
  #
  ##############################################################################

  def rs_format_boolean(v,f); v ? 'true' : 'false'; end
  def rs_parse_boolean(v,f); v == 'true'; end

  def rs_format_rss_type(v,f)
    v.to_s.split.map(&:to_sym).map(&:l).join(' OR ')
  end

  def rs_parse_rss_type(v,f)
    map = {}
    for type in [:all] + RssLog.all_types.map(&:to_sym)
      map[type.l.downcase.strip_squeeze] = type.to_s
    end
    vals = v.to_s.split(/\s+OR\s+/).map do |x|
      if y = map[x.downcase.strip_squeeze]
        y
      else
        raise(:runtime_refine_search_invalid_rss_type.t(:value => x))
      end
    end.uniq
    vals = ['all'] if vals.include?('all')
    vals.join(' ')
  end

  # ----------------------------
  #  Object parsers.
  # ----------------------------

  def rs_format_image(v,f);        rs_format_object(Image, v,f);       end
  def rs_format_location(v,f);     rs_format_object(Location, v,f);    end
  def rs_format_name(v,f);         rs_format_object(Name, v,f);        end
  def rs_format_observation(v,f);  rs_format_object(Observation, v,f); end
  def rs_format_species_list(v,f); rs_format_object(SpeciesList, v,f); end
  def rs_format_user(v,f);         rs_format_object(User, v,f);        end

  def rs_parse_image(v,f);        rs_parse_object(Image, v,f);       end
  def rs_parse_location(v,f);     rs_parse_object(Location, v,f);    end
  def rs_parse_name(v,f);         rs_parse_object(Name, v,f);        end
  def rs_parse_observation(v,f);  rs_parse_object(Observation, v,f); end
  def rs_parse_species_list(v,f); rs_parse_object(SpeciesList, v,f); end
  def rs_parse_user(v,f);         rs_parse_object(User, v,f);        end

  def rs_format_images(v,f);        rs_format_objects(Image, v,f);       end
  def rs_format_locations(v,f);     rs_format_objects(Location, v,f);    end
  def rs_format_names(v,f);         rs_format_objects(Name, v,f);        end
  def rs_format_observations(v,f);  rs_format_objects(Observation, v,f); end
  def rs_format_species_lists(v,f); rs_format_objects(SpeciesList, v,f); end
  def rs_format_users(v,f);         rs_format_objects(User, v,f);        end

  def rs_parse_images(v,f);        rs_parse_objects(Image, v,f);       end
  def rs_parse_locations(v,f);     rs_parse_objects(Location, v,f);    end
  def rs_parse_names(v,f);         rs_parse_objects(Name, v,f);        end
  def rs_parse_observations(v,f);  rs_parse_objects(Observation, v,f); end
  def rs_parse_species_lists(v,f); rs_parse_objects(SpeciesList, v,f); end
  def rs_parse_users(v,f);         rs_parse_objects(User, v,f);        end

  def rs_format_object(model, val, field)
    if obj = model.safe_find(val)
      case model.name
      when 'Location'
        obj.display_name
      when 'Name'
        obj.search_name
      when 'Project'
        obj.title
      when 'SpeciesList'
        obj.title
      when 'User'
        if !obj.name.blank?
          "#{obj.login} <#{obj.name}>"
        else
          obj.login
        end
      else
        obj.id.to_s
      end
    else
      :refine_search_unknown_object.l(:type => model.type_tag, :id => val)
    end
  end

  def rs_parse_object(model, val, field)
    val = val.strip_squeeze
    if val.blank?
      nil
    elsif val.match(/^\d+$/)
      val
    else
      case model.name
      when 'Location'
        obj = Location.find_by_display_name(val)
      when 'Name'
        obj = Name.find_by_search_name(val) ||
              Name.find_by_text_name(val)
      when 'SpeciesList'
        obj = SpeciesList.find_by_title(val)
      when 'User'
        val2 = val.sub(/ *<.*/, '')
        obj = User.find_by_login(val2) ||
              User.find_by_name(val2)
      else
        raise(:runtime_refine_search_expect_id.t(:type => model.type_tag,
                :field => field.label.t, :value => val))
      end
      if !obj
        raise(:runtime_refine_search_object_not_found.t(:type => model.type_tag,
                :field => field.label.t, :value => val))
      end
      obj.id.to_s
    end
  end

  def rs_format_objects(model, val, field)
    val = [] if val.blank?
    val.map {|v| rs_format_object(model, v, field)}.join(' OR ')
  end

  def rs_parse_objects(model, val, field)
    val = val.strip_squeeze
    val.split(/\s+OR\s+/).map {|v| rs_parse_object(model, v, field)}
  end

  # ----------------------------
  #  Date parsers.
  # ----------------------------

  def rs_format_date(val, field)
    if val == '0' || val.blank?
      ''
    elsif val.match(/^\d\d\d\d/)
      y, m, d = val.split('-')
      val  =  '%04d' % y
      val += '-%02d' % m if m
      val += '-%02d' % d if d
      val
    elsif val.match(/-/)
      m, d = val.split('-')
      :date_helper_month_names.l[m.to_i] + (' %d' % d)
    else
      :date_helper_month_names.l[val.to_i]
    end
  end

  def rs_format_time(val, field)
    if val == '0' || val.blank?
      ''
    else
      y, m, d, h, n, s = val.to_s.split('-')
      val  =  '%04d' % y
      val += '-%02d' % m if m
      val += '-%02d' % d if d
      val += ' %02d' % h if h
      val += ':%02d' % n if n
      val += ':%02d' % s if s
      val
    end
  end

  def rs_format_dates(val, field)
    val = [] if val.blank?
    val.map {|v| rs_format_date(v, field)}
  end

  def rs_format_times(val, field)
    val = [] if val.blank?
    val.map {|v| rs_format_time(v, field)}
  end

  def rs_parse_date(val, field)
    val = val.strip_squeeze
    if val.match(/^(\d\d\d\d)([- :](\d\d?|[a-z]{3,}))?([- :](\d\d?))?$/i)
      y, m, d = $1, $3, $5
      m = rs_parse_month(m) if m && m.length > 2
      [y, m, d].reject(&:nil?).join('-')
    elsif val.to_s.match(/^(\d\d?|[a-z]{3,})([- :](\d\d?))?$/i)
      m, d = $1, $3
      m = rs_parse_month(m) if m && m.length > 2
      [m, d].reject(&:nil?).join('-')
    elsif val.blank?
      '0'
    else
      raise(:runtime_invalid.t(:type => :date, :value => val))
    end
  end

  def rs_parse_time(val, field)
    val = val.strip_squeeze
    if val.match(/^(\d\d\d\d)([- :](\d\d?|[a-z]{3,}))?([- :](\d\d?))?([- :](\d\d?))?([- :](\d\d?))?([- :](\d\d?))?(am|pm)?$/i)
      y, m, d, h, n, s, am = $1, $3, $5, $7, $9, $11, $12
      m = rs_parse_month(m)      if m && m.length > 2
      h = '%02s' % (h.to_i + 12) if h && am && am.downcase == 'pm'
      [y, m, d, h, n, s].reject(&:nil?).join('-')
    elsif val.blank?
      '0'
    else
      raise(:runtime_invalid.t(:type => :time, :value => val))
    end
  end

  def rs_parse_month(str)
    str = str.downcase
    m = :date_helper_month_names.l[1..-1].map(&:downcase).index(str) ||
        :date_helper_abbr_month_names.l[1..-1].map(&:downcase).index(str)
    return '%02d' % (m + 1)
  end

  def rs_parse_times(val, field)
    val = [] if val.blank?
    [rs_parse_time(val[0], field),
     rs_parse_time(val[1], field)]
  end

  def rs_parse_dates(val, field)
flash_notice("Parsing #{field.name}: #{val.inspect}")
    val = [] if val.blank?
    [rs_parse_date(val[0], field),
     rs_parse_date(val[1], field)]
  end

  ##############################################################################
  #
  #  :section: Mechanics
  #
  ##############################################################################

  # Get Array of conditions that the user can use to narrow their search.
  def refine_search_get_fields(query)
    results = []
    query.parameter_declarations.each do |key, val|
      name = key.to_s.sub(/(\?)$/,'').to_sym
      required = !$1
      id = MODEL_FIELDS[query.model_symbol][name] rescue nil
      id ||= FLAVOR_FIELDS[query.flavor][name]    rescue nil
      id ||= name
      if field = FIELDS.select {|f| f.id == id}.first
        field = field.dup
        field.required = required
        field.declare  = val
        results << field
      end
    end
    order = FIELD_ORDER[query.model_symbol]
    return results.sort_by {|f| order.index(f.id)}
  end

  # Fill in form values from query first time through.
  def refine_search_initialize_values(fields, values, query)
    for field in fields
      val = query.params[field.name]
      val = field.default if val.nil?
      case (proc = field.format || field.parse)
      when Symbol
        val = send("rs_format_#{proc}", val, field)
      when Proc
        val = proc.call(val, field)
      end
      if field.input.to_s.match(/(\d+)$/)
        n = $1.to_i
        for i in 1..n
          values.send("#{field.name}_#{i}=", val[i-1])
        end
      else
        values.send("#{field.name}=", val)
      end
    end
  end

  # Clone the given parameter Hash, cleaning out all parameters that do not
  # apply to this model/flavor.  (This only applies when changing flavor.)
  def refine_search_clone_params(query, params2)
    params = {}
    query.parameter_declarations.each do |key, val|
      key = key.to_s.sub(/\?$/,'').to_sym
      if params2.has_key?(key)
        params[key] = params2[key]
      end
    end
    return params
  end

  # Apply one or more additional conditions to the query.
  def refine_search_change_params(fields, values, params)
    errors = []
    for field in fields
      begin
        val = refine_search_parse(field, values)
        if val.nil?
          val = field.default
        end
        if val.nil? && field.required
          flash_error(:runtime_refine_search_field_required.t(:field =>
                                                              field.label))
          errors << field.name
        end
      rescue => e
        flash_error(e)
        flash_error(e.backtrace.join("<br>"))
        errors << field.name
        val = field.default
      end
      if params[field.name] != val
        params[field.name] = val
        any_changes = true
      end
    end
    return errors
  end

  # Parse a single value (or tuple of values).
  def refine_search_parse(field, values)
    result = nil
    if field.input.to_s.match(/(\d+)$/)
      n = $1.to_i
      val = []
      for i in 1..n
        val << refine_search_get_value(field, values, i)
      end
      if val.none?(&:blank?)
        case (proc = field.parse)
        when Symbol
          result = send("rs_parse_#{proc}", val, field)
        when Proc
          result = proc.call(val, field)
        else
          result = val
        end
      end
    else
      val = refine_search_get_value(field, values)
      if !val.blank?
        case field.parse
        when Symbol
          result = send("rs_parse_#{field.parse}", val, field)
        when Proc
          result = field.parse.call(val, field)
        else
          result = val
        end
      end
    end
    return result
  end

  # Retrieve a single value, giving it the default if one exists.
  def refine_search_get_value(field, values, i=nil)
    name = i ? :"#{field.name}_#{i}" : field.name
    val = values.send(name).to_s
    if val.blank? && !field.default.nil?
      val = field.default.to_s
      values.send("#{name}=", val)
    end
    return val
  end

  # Kludge up a "fake" field to let user change the query flavor.
  def refine_search_flavor_field
    menu = []
    for model, list in Query.allowed_model_flavors
      model = model.to_s.underscore.to_sym
      for flavor in list
        menu << [:"Query_help_#{model}_#{flavor}", "#{model} #{flavor}"]
      end
    end
    menu = menu.sort_by {|x| x[0].to_s}
    Field.new(
      :id    => :model_flavor,
      :name  => :model_flavor,
      :label => :refine_search_model_flavor,
      :help  => :refine_search_model_flavor_help,
      :input => :menu,
      :opts  => menu,
      :required => true
    )
  end
end
