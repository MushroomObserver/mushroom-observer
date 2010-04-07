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
    attr_accessor :opts       # Menu options: [ [label, val], ... ]
    attr_accessor :default    # Default value (if non-blank).
    attr_accessor :blank      # Include blank in menu?
    attr_accessor :format     # Formatter: method name or Proc.
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
    :rss_log => { :type => :rss_type },
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
      :autocomplete => :location
    ),
    Field.new(
      :id    => :advanced_search_name,
      :name  => :name,
      :label => :refine_search_advanced_search_name,
      :input => :text,
      :autocomplete => :name
    ),
    Field.new(
      :id    => :advanced_search_user,
      :name  => :user,
      :label => :refine_search_advanced_search_user,
      :input => :text,
      :autocomplete => :user
    ),

    # Include all children or only immediate children?
    Field.new(
      :id    => :all_children,
      :name  => :all,
      :label => :refine_search_all_children,
      :input => :menu,
      :opts  => [
        [:refine_search_all_children_true, true],
        [:refine_search_all_children_false, false],
      ],
      :default => :either,
      :blank => false
    ),

    # Include deprecated names?
    Field.new(
      :id    => :deprecated,
      :name  => :deprecated,
      :label => :refine_search_deprecated,
      :input => :menu,
      :opts  => [
        [:refine_search_deprecated_no, :no],
        [:refine_search_deprecated_only, :only],
        [:refine_search_deprecated_either, :either],
      ],
      :default => :either,
      :blank => false
    ),

    # Specify a given (defined) location.
    Field.new(
      :id    => :location,
      :name  => :location,
      :label => :Location,
      :input => :text,
      :autocomplete => :location,
      :format => :location,
      :parse => :location
    ),

    # Specify a given (undefined) location.
    Field.new(
      :id    => :location_where,
      :name  => :location,
      :label => :Location,
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
        [:refine_search_misspellings_no, :no],
        [:refine_search_misspellings_only, :only],
        [:refine_search_misspellings_either, :either],
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
      :format => :name,
      :parse => :name
    ),

    # Include observations whose nonconsensus names match a given name?
    Field.new(
      :id    => :nonconsensus,
      :name  => :nonconsensus,
      :label => :refine_search_nonconsensus,
      :input => :menu,
      :opts  => [
        [:refine_search_nonconsensus_no, :no],
        [:refine_search_nonconsensus_all, :all],
        [:refine_search_nonconsensus_exclusive, :exclusive],
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
      :format => :observation,
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
      :input => :menu,
      :opts  => [
        [:refine_search_rss_log_type_all, :all],
      ] + RssLog.all_types.map { |type|
        ["#{type}s".upcase.to_sym, type]
      },
      :default => :all,
      :blank => false
    ),

    # Specify a given user.
    Field.new(
      :id    => :species_list,
      :name  => :species_list,
      :label => :Species_list,
      :input => :text,
      :autocomplete => :species_list,
      :format => :species_list,
      :parse => :species_list
    ),

    # Include observations of synonyms of a given name?
    Field.new(
      :id    => :synonyms,
      :name  => :synonyms,
      :label => :refine_search_synonyms,
      :input => :menu,
      :opts  => [
        [:refine_search_synonyms_no, :no],
        [:refine_search_synonyms_all, :all],
        [:refine_search_synonyms_exclusive, :exclusive],
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
      :format => :user,
      :parse => :user
    ),
  ]

  ##############################################################################
  #
  #  :section: Formaters and Parsers
  #
  ##############################################################################

  def rs_format_location(v);     rs_format_object(Location, v);    end
  def rs_format_name(v);         rs_format_object(Name, v);        end
  def rs_format_observation(v);  rs_format_object(Observation, v); end
  def rs_format_species_list(v); rs_format_object(SpeciesList, v); end
  def rs_format_user(v);         rs_format_object(User, v);        end

  def rs_parse_location(v);     rs_parse_object(Location, v);    end
  def rs_parse_name(v);         rs_parse_object(Name, v);        end
  def rs_parse_observation(v);  rs_parse_object(Observation, v); end
  def rs_parse_species_list(v); rs_parse_object(SpeciesList, v); end
  def rs_parse_user(v);         rs_parse_object(User, v);        end

  def rs_format_locations(v);     rs_format_objects(Location, v);    end
  def rs_format_names(v);         rs_format_objects(Name, v);        end
  def rs_format_observations(v);  rs_format_objects(Observation, v); end
  def rs_format_species_lists(v); rs_format_objects(SpeciesList, v); end
  def rs_format_users(v);         rs_format_objects(User, v);        end

  def rs_parse_locations(v);     rs_parse_objects(Location, v);    end
  def rs_parse_names(v);         rs_parse_objects(Name, v);        end
  def rs_parse_observations(v);  rs_parse_objects(Observation, v); end
  def rs_parse_species_lists(v); rs_parse_objects(SpeciesList, v); end
  def rs_parse_users(v);         rs_parse_objects(User, v);        end

  def rs_format_object(model, val)
    if obj = model.safe_find(val)
      case model.name
      when 'Name'
        obj.search_name
      when 'User'
        if !obj.name.blank?
          "#{obj.login} <#{obj.name}>"
        else
          obj.login
        end
      else
        obj.text_name
      end
    else
      :refine_search_unknown_object.l(:type => model.type_tag, :id => val)
    end
  end

  def rs_format_objects(model, val)
    val
  end

  def rs_parse_object(model, val)
    val
  end

  def rs_parse_objects(model, val)
    val
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
  #   type = model.name.underscore.to_sym
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
  def refine_search_get_fields(query, values)
    results = []

flash_notice((query.parameter_declarations.keys - [:join?, :title?, :tables?, :where?, :group?, :order?, :by?]).inspect)

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

        # Prepare current value for display.
        val = values.send(name)
        val = query.params[name] if val.nil?
        val = field.default      if val.nil? && field.default
        case field.format
        when Symbol
          val = send("rs_format_#{field.format}", val)
        when Proc
          val = field.format.call(val)
        end
        values.send("#{name}=", val)
      end
    end

    order = RS_FIELD_ORDER[query.model_symbol]
    results = results.sort_by {|f| order.index(f.id)}
    results = nil if results.empty?
    return results
  end

  # Apply one or more additional conditions to the query.
  def refine_search_apply_changes(query, fields, values)
    any_changes = false
    any_errors  = false
    params = query.params.dup

    for field in fields
      if field.input.to_s.match(/2$/)
        val1 = values.send("#{field.name}_1").to_s
        val2 = values.send("#{field.name}_2").to_s
      else
        val1 = values.send(field.name).to_s
        val2 = nil
      end

      case fields.parse
      when Symbol
        if val2
          val = send("rsp_#{fields.parse}", val1, val2)
        else
          val = send("rsp_#{fields.parse}", val1)
        end
      when Proc
        if val2
          val = field.parse.call(val1, val2)
        else
          val = field.parse.call(val1)
        end
      else
        if val2
          val = [val1, val2]
        else
          val = val1
        end
      end

      params[field.name] = val
    end

    # Create and initialize the new query to test it out.  If this succeeds,
    # we will send the user back to the index to see the new results.
    result = nil
    if any_errors
      # Already flashed errors when they occurred.
    elsif !any_changes
      flash_error(:runtime_no_conditions.t) if !@goto_index
    else
      begin
        query2 = Query.lookup(query.model, query.flavor, params)
        query2.initialize_query
        query2.save
        result = query2
      rescue => e
        flash_error(e)
      end
    end

    # Return new query if changes made successfully, otherwise we'll make all
    # the changes again next time.
    return result
  end
end
