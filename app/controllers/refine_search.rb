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

  RS_FIELD_ORDER = {

    :Comment => [
      :pattern,
      :user,
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
    ],

    :LocationDescription => [
      :user,
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
    ],

    :NameDescription => [
      :user,
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
    ],

    :Project => [
      :pattern,
    ],

    :RssLog => [
      :rss_type,
    ],

    :SpeciesList => [
      :pattern,
      :user,
      :location,
      :location_where,
    ],

    :User => [
      :pattern,
    ],
  }

  # --------------------------------------
  #  Flavor- and model-specific aliases.
  # --------------------------------------

  RS_FLAVOR_FIELDS = {
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

  RS_MODEL_FIELDS = {
    :RssLog => { :type => :rss_type },
  }

  # ----------------------------
  #  Field specifications.
  # ----------------------------

  RS_FIELDS = [

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
    val.map {|v| rs_format_object(model, v)}.join(' OR ')
  end

  def rs_parse_objects(model, val, field)
    val = val.strip_squeeze
    val.split(/\s+OR\s+/).map {|v| rs_parse_object(model, v)}
  end

  # def refine_search_date(query, params, val, args)
  #   f = args[:field]
  #   val = val.to_s.strip_squeeze
  #   unless val.match(/^(\d\d\d\d)((-)(\d\d\d\d))$/) or
  #          val.match(/^([a-z]\w+)((-)([a-z]\w+))$/i) or
  #          val.match(/^([\w\-]+)( (- |to |a )?([\w\-]+))?$/)
  #     raise :runtime_invalid.t(:type => :date, :value => val)
  #   end
  #   date1, date2 = $1, $4
  #   y1, m1, d1 = refine_search_parse_date(date1)
  #   if date2
  #     y2, m2, d2 = refine_search_parse_date(date2)
  #     if (!!y1 != !!y2) or (!!m1 != !!m2) or (!!d1 != !!d2)
  #       raise :runtime_dates_must_be_same_format.t
  #     end
  #
  #     # Two full dates.
  #     if y1
  #       params[:where] << "#{f} >= '%04d-%02d-%02d' AND #{f} <= '%04d-%02d-%02d'" % [y1, m1 || 1, d1 || 1, y2, m2 || 12, d2 || 31]
  #
  #     # Two months and days.
  #     elsif d1
  #       if "#{m1}#{d1}".to_i < "#{m2}#{d2}".to_i
  #         params[:where] << "(MONTH(#{f}) > #{m1} OR MONTH(#{f}) = #{m1} AND DAY(#{f}) >= #{d1}) AND (MONTH(#{f}) < #{m2} OR MONTH(#{f}) = #{m2} AND DAY(#{f}) <= #{d2})"
  #       else
  #         params[:where] << "MONTH(#{f}) > #{m1} OR MONTH(#{f}) = #{m1} AND DAY(#{f}) >= #{d1} OR MONTH(#{f}) < #{m2} OR MONTH(#{f}) = #{m2} AND DAY(#{f}) <= #{d2}"
  #       end
  #
  #     # Two months.
  #     else
  #       if m1 < m2
  #         params[:where] << "MONTH(#{f}) >= #{m1} AND MONTH(#{f}) <= #{m2}"
  #       else
  #         params[:where] << "MONTH(#{f}) >= #{m1} OR MONTH(#{f}) <= #{m2}"
  #       end
  #     end
  #
  #   # One full date.
  #   elsif y1 && m1 && d1
  #     params[:where] << "#{f} = '%04d-%02d-%02d'" % [y1, m1, d2]
  #   elsif y1 && m1
  #     params[:where] << "YEAR(#{f}) = #{y1} AND MONTH(#{f}) = #{m1}"
  #   elsif y1
  #     params[:where] << "YEAR(#{f}) = #{y1}"
  #
  #   # One month (and maybe day).
  #   elsif d1
  #     params[:where] << "MONTH(#{f}) = #{m1} AND DAY(#{f}) = #{d1}"
  #   else
  #     params[:where] << "MONTH(#{f}) = #{m1}"
  #   end
  # end
  #
  # def refine_search_time(query, params, val, args)
  #   f = args[:field]
  #   val = val.to_s.strip_squeeze
  #   if !val.match(/^([\w\-\:]+)( (- |to |a )?([\w\-\:]+))?$/)
  #     raise :runtime_invalid.t(:type => :date, :value => val)
  #   end
  #   date1, date2 = $1, ($4 || $1)
  #   y1, m1, d1, h1, n1, s1 = refine_search_parse_time(date1)
  #   y2, m2, d2, h2, n2, s2 = refine_search_parse_time(date2)
  #   m1 ||=  1; d1 ||=  1; h1 ||=  0; n1 ||=  0; s1 ||=  0
  #   m2 ||= 12; d2 ||= 31; h2 ||= 23; n2 ||= 59; s2 ||= 59
  #   params[:where] << "#{f} >= '%04d-%02d-%02d %02d:%02d:%02d' AND #{f} <= '%04d-%02d-%02d %02d:%02d:%02d'" % [y1, m1, d1, h1, n1, s1, y2, m2, d2, h2, n2, s2]
  # end
  #
  # def refine_search_parse_date(str)
  #   y = m = d = nil
  #   if str.match(/^(\d\d\d\d)(-(\d\d|[a-z]{3,}))?(-(\d\d))?$/i)
  #     y, m, d = $1, $3, $5
  #     if m && m.length > 2
  #       m = :date_helper_month_names.l.index(m) ||
  #           :date_helper_abbr_month_names.l.index(m)
  #     end
  #   elsif str.match(/^(\d\d|[a-z]{3,})(-(\d\d))?$/i)
  #     m, d = $1, $3
  #     m = refine_search_parse_month(m) if m && m.length > 2
  #   else
  #     raise :runtime_invalid.t(:type => :date, :value => str)
  #   end
  #   return [y, m, d].map {|x| x && x.to_i}
  # end
  #
  # def refine_search_parse_time(str)
  #   if !str.match(/^(\d\d\d\d)(-(\d\d|[a-z]{3,}))?(-(\d\d))?(:(\d\d))?(:(\d\d))?(:(\d\d))?(am|pm)?$/i)
  #     raise :runtime_invalid.t(:type => :date, :value => str)
  #   end
  #   y, m, d, h, n, s, am = $1, $3, $5, $7, $9, $11, $12
  #   if m && m.length > 2
  #     m = :date_helper_month_names.l.index(m) ||
  #         :date_helper_abbr_month_names.l.index(m)
  #   end
  #   h = h.to_i + 12 if h && am && am.downcase == 'pm'
  #   return [y, m, d, h, n, s].map {|x| x && x.to_i}
  # end
  #
  # def refine_search_parse_month(str)
  #   result = nil
  #   str = str.downcase
  #   for list in [
  #     :date_helper_month_names.l,
  #     :date_helper_abbr_month_names.l
  #   ]
  #     result = list.map {|v| v.is_a?(String) && v.downcase }.index(str)
  #     break if result
  #   end
  #   return result
  # end
  #
  # def refine_search_lookup(query, params, val, args)
  #   model = args[:model]
  #   type = model.type_tag
  #   val = val.to_s.strip_squeeze
  #   ids = objs = nil
  #
  #   # Supplied one or more ids.
  #   if val.match(/^\d+(,? ?\d+)*$/)
  #     ids = val.split(/[, ]+/).map(&:to_i)
  #     if args[:method]
  #       objs = model.all(:conditions => ['id IN (?)', ids])
  #     end
  #
  #   # Supplied full or partial string.
  #   else
  #     case type
  #     when :name
  #       objs = model.find_all_by_search_name(val)
  #       objs = model.find_all_by_text_name(val) if objs.empty?
  #       if objs.empty?
  #         val  = query.clean_pattern(val)
  #         objs = model.all(:conditions => "search_name LIKE '#{val}%'")
  #       end
  #     when :species_list
  #       objs = model.find_all_by_title(val)
  #       if objs.empty?
  #         val  = query.clean_pattern(val)
  #         objs = model.all(:conditions => "title LIKE '#{val}%'")
  #       end
  #     when :user
  #       val.sub!(/ *<.*>/, '')
  #       objs = model.find_all_by_login(val)
  #       objs = model.find_all_by_name(val) if objs.empty?
  #       if objs.empty?
  #         val  = query.clean_pattern(val)
  #         objs = model.all(:conditions => "login LIKE '#{val}%' OR name LIKE '#{val}%'")
  #       end
  #     else
  #       raise "Unsupported model in lookup condition: #{args[:model].name.inspect}"
  #     end
  #   end
  #
  #   if objs && objs.empty?
  #     raise :runtime_no_matches.t(:type => type)
  #   end
  #
  #   # Call an additional method on each result?
  #   if method = args[:method]
  #     if !objs.first.respond_to?(method)
  #       raise "Invalid :method for lookup condition: #{method.inspect}"
  #     end
  #     if method.to_s.match(/_ids$/)
  #       ids = objs.map(&method).flatten
  #     else
  #       ids = objs.map(&method).flatten.map(&:id)
  #     end
  #   elsif objs
  #     ids = objs.map(&:id)
  #   end
  #
  #   # Put together final condition.
  #   ids = ids.uniq.map(&:to_s).join(',')
  #   params[:where] << "#{args[:field]} IN (#{ids})"
  # end

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
      id = RS_MODEL_FIELDS[query.model_symbol][name] rescue nil
      id ||= RS_FLAVOR_FIELDS[query.flavor][name]    rescue nil
      id ||= name
      if field = RS_FIELDS.select {|f| f.id == id}.first
        field = field.dup
        field.required = required
        field.declare  = val
        results << field
      end
    end
    order = RS_FIELD_ORDER[query.model_symbol]
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
      values.send("#{field.name}=", val)
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
