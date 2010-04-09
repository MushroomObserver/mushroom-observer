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
    attr_accessor :id         # Our parameter name (for disambiguation) (Symbol).
    attr_accessor :name       # Parameter name (Symbol).
    attr_accessor :label      # Label of form field (Symbol).
    attr_accessor :input      # Input type: :text, :text2, :menu, :menu2
    attr_accessor :autocomplete # Autocompleter: :name, :user, etc.
    attr_accessor :tokens     # Allow multiple values (OR) in autocompletion?
    attr_accessor :primer     # Prime auto-completer with Array of String's.
    attr_accessor :opts       # Menu options: [ [label, val], ... ]
    attr_accessor :default    # Default value (if non-blank).
    attr_accessor :blank      # Include blank in menu?
    attr_accessor :num        # Number of fields to include if variable.
    attr_accessor :word       # Word in between pairs of texts / menus.
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
      :synonyms,
      :nonconsensus,
      :location_defined,
      :location_undefined,
      :species_list,
      :observation,
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
      :synonyms,
      :nonconsensus,
      :location_defined,
      :location_undefined,
      :species_list,
      :observation,
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
      :all_children,
      :location_defined,
      :location_undefined,
      :species_list,
      :observation,
      :deprecated,
      :misspellings,
      :created,
      :modified,
      :users,
      :synonym_names,
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
      :all_children,
      :synonyms,
      :nonconsensus,
      :location_defined,
      :location_undefined,
      :species_list,
      :observation,
      :created,
      :modified,
      :date,
      :users,
      :names,
      :synonym_names,
      :locations,
      :species_lists,
      :confidence,
      :is_col_loc,
      :has_specimen,
      :has_name,
      :has_location,
      :has_images,
      :has_votes,
      :has_notes,
      :notes_has,
      :has_comments,
      :comments_has,
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
      :location_defined,
      :location_undefined,
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

  # ----------------------------
  #  Field specifications.
  # ----------------------------

  def rs_field_all(model, flavor)
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
    )
  end

  def rs_field_comments_has(model, flavor)
    Field.new(
      :name  => :comments_has,
      :label => :refine_search_comments_has,
      :input => :textN,
      :parse => :stringN,
      :word  => 'AND'
    )
  end

  def rs_field_confidence(model, flavor)
    Field.new(
      :name  => :confidence,
      :label => :refine_search_confidence,
      :input => :menu2,
      :word  => :VOTE,
      :opts  => Vote.confidence_menu.map {|a,b| [a,b.to_s]},
      :blank => true
    )
  end

  def rs_field_content(model, flavor)
    Field.new(
      :id    => :advanced_search_content,
      :name  => :content,
      :label => :refine_search_advanced_search_content,
      :input => :textN,
      :parse => :stringN,
      :word  => 'AND'
    )
  end

  def rs_field_created(model, flavor)
    Field.new(
      :name   => :created,
      :label  => :refine_search_created,
      :input  => :text2,
      :word   => :TIME,
      :parse  => :time2
    )
  end

  def rs_field_date(model, flavor)
    Field.new(
      :name   => :date,
      :label  => :"refine_search_date_#{model.to_s.underscore}",
      :input  => :text2,
      :word   => :DATE,
      :parse  => :date2
    )
  end

  def rs_field_deprecated(model, flavor)
    Field.new(
      :name  => :deprecated,
      :label => :refine_search_deprecated,
      :input => :menu,
      :opts  => [
        [:refine_search_deprecated_no, 'no'],
        [:refine_search_deprecated_only, 'only'],
        [:refine_search_deprecated_either, 'either'],
      ],
      :default => 'either',
      :blank => false
    )
  end

  def rs_field_has_comments(model, flavor)
    Field.new(
      :name  => :has_comments,
      :label => :refine_search_has_comments,
      :input => :menu,
      :opts  => [[:yes, 'yes']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_has_images(model, flavor)
    Field.new(
      :name  => :has_images,
      :label => :refine_search_has_images,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_has_location(model, flavor)
    Field.new(
      :name  => :has_location,
      :label => :refine_search_has_location,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_has_name(model, flavor)
    Field.new(
      :name  => :has_name,
      :label => :refine_search_has_name,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_has_notes(model, flavor)
    Field.new(
      :name  => :has_notes,
      :label => :refine_search_has_notes,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_has_specimen(model, flavor)
    Field.new(
      :name  => :has_specimen,
      :label => :refine_search_has_specimen,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_has_votes(model, flavor)
    Field.new(
      :name  => :has_votes,
      :label => :refine_search_has_votes,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_is_col_loc(model, flavor)
    Field.new(
      :name  => :is_col_loc,
      :label => :refine_search_is_col_loc,
      :input => :menu,
      :opts  => [[:yes, 'true'], [:no, 'false']],
      :default => nil,
      :blank => true
    )
  end

  def rs_field_location(model, flavor)
    if flavor == :advanced_search
      Field.new(
        :id    => :advanced_search_location,
        :name  => :location,
        :label => :refine_search_advanced_search_location,
        :input => :text,
        :autocomplete => :location,
        :tokens => true
      )
    elsif (flavor == :at_location) or
          (flavor == :with_observations_at_location)
      Field.new(
        :name  => :location,
        :label => :refine_search_location_defined,
        :input => :text,
        :parse => :location,
        :autocomplete => :location
      )
    elsif (flavor == :at_where) or
          (flavor == :with_observations_at_where)
      Field.new(
        :name  => :location,
        :label => :refine_search_location_undefined,
        :input => :text,
        :parse => :location,
        :autocomplete => :location
      )
    end
  end

  def rs_field_locations(model, flavor)
    Field.new(
      :name   => :locations,
      :label  => :refine_search_locations,
      :input  => :textN,
      :autocomplete => :location,
      :tokens => true,
      :parse  => :location_nameN
    )
  end

  def rs_field_misspellings(model, flavor)
    Field.new(
      :name  => :misspellings,
      :label => :refine_search_misspellings,
      :input => :menu,
      :opts  => [
        [:refine_search_misspellings_no, 'no'],
        [:refine_search_misspellings_only, 'only'],
        [:refine_search_misspellings_either, 'either'],
      ],
      :default => 'no',
      :blank => false
    )
  end

  def rs_field_modified(model, flavor)
    if model == :RssLog
      Field.new(
        :name   => :modified,
        :label  => :refine_search_rss_modified,
        :input  => :text2,
        :word   => :TIME,
        :parse  => :time2
      )
    else
      Field.new(
        :name   => :modified,
        :label  => :refine_search_modified,
        :input  => :text2,
        :word   => :TIME,
        :parse  => :time2
      )
    end
  end

  def rs_field_name(model, flavor)
    if flavor == :advanced_search
      Field.new(
        :id    => :advanced_search_name,
        :name  => :name,
        :label => :refine_search_advanced_search_name,
        :input => :text,
        :autocomplete => :name,
        :tokens => true
      )
    else
      Field.new(
        :name  => :name,
        :label => :Name,
        :input => :text,
        :autocomplete => :name,
        :parse => :name
      )
    end
  end

  def rs_field_names(model, flavor)
    Field.new(
      :name   => :names,
      :label  => :refine_search_names,
      :input  => :textN,
      :autocomplete => :name,
      :tokens => true,
      :parse  => :name_nameN
    )
  end

  def rs_field_notes_has(model, flavor)
    Field.new(
      :name  => :notes_has,
      :label => :refine_search_notes_has,
      :input => :textN,
      :parse => :stringN,
      :word  => 'AND'
    )
  end

  def rs_field_synonym_names(model, flavor)
    Field.new(
      :name   => :synonym_names,
      :label  => :refine_search_synonym_names,
      :input  => :textN,
      :autocomplete => :name,
      :tokens => true,
      :parse  => :name_nameN
    )
  end

  def rs_field_nonconsensus(model, flavor)
    Field.new(
      :name  => :nonconsensus,
      :label => :refine_search_nonconsensus,
      :input => :menu,
      :opts  => [
        [:refine_search_nonconsensus_no, 'no'],
        [:refine_search_nonconsensus_all, 'all'],
        [:refine_search_nonconsensus_exclusive, 'exclusive'],
      ],
      :default => 'no',
      :blank => false
    )
  end

  def rs_field_observation(model, flavor)
    Field.new(
      :name  => :observation,
      :label => :Observation,
      :input => :text,
      :parse => :observation
    )
  end

  def rs_field_pattern(model, flavor)
    Field.new(
      :name  => :pattern,
      :label => :"refine_search_pattern_#{model.to_s.underscore}",
      :input => :textN,
      :parse => :stringN,
      :word  => 'AND'
    )
  end

  def rs_field_species_list(model, flavor)
    Field.new(
      :name  => :species_list,
      :label => :Species_list,
      :input => :text,
      :autocomplete => :species_list,
      :parse => :species_list
    )
  end

  def rs_field_species_lists(model, flavor)
    Field.new(
      :name   => :species_lists,
      :label  => :refine_search_species_lists,
      :input  => :textN,
      :autocomplete => :species_list,
      :tokens => true,
      :parse  => :species_list_nameN
    )
  end

  def rs_field_synonyms(model, flavor)
    Field.new(
      :name  => :synonyms,
      :label => :refine_search_synonyms,
      :input => :menu,
      :opts  => [
        [:refine_search_synonyms_no, 'no'],
        [:refine_search_synonyms_all, 'all'],
        [:refine_search_synonyms_exclusive, 'exclusive'],
      ],
      :default => 'no',
      :blank => false
    )
  end

  def rs_field_type(model, flavor)
    Field.new(
      :id    => :rss_type,
      :name  => :type,
      :label => :refine_search_rss_log_type,
      :input => :checkboxes,
      :opts  => RssLog.all_types.map do |val|
        [ :"#{val.upcase}S", val ]
      end,
      :parse => :rss_type,
      :default => 'all'
    )
  end

  def rs_field_user(model, flavor)
    if flavor == :advanced_search
      Field.new(
        :id    => :advanced_search_user,
        :name  => :user,
        :label => :refine_search_advanced_search_user,
        :input => :text,
        :autocomplete => :user,
        :tokens => true
      )
    else
      Field.new(
        :name  => :user,
        :label => :User,
        :input => :text,
        :autocomplete => :user,
        :parse => :user
      )
    end
  end

  def rs_field_users(model, flavor)
    Field.new(
      :name   => :users,
      :label  => :refine_search_users,
      :input  => :textN,
      :autocomplete => :user,
      :tokens => true,
      :parse  => :userN
    )
  end

  ##############################################################################
  #
  #  :section: Formaters and Parsers
  #
  #  rs_format_blah::
  #    This takes a value from query.params and formats it into a single
  #    scalar or Array of scalars (depending on input type).  Return nil in
  #    any case if there is no value.
  #
  #  rs_parse_blah::
  #    This takes essentially whatever value rs_format_blah returns and turns
  #    it back into something that gets stored in query.params.
  #
  #  input types::
  #    text::       Value of string to place in field.
  #    text2::      Pair of two values, e.g. dates or times.
  #    textN::      Array of values, will create N + 1 text fields.
  #    menu::       Value of selected item.
  #    menu2::      Pair of values, e.g. confidence levels.
  #    checkboxes:: Array of values of checked check-boxes.
  #
  ##############################################################################

  def rs_format_boolean(v,f); v ? 'true' : 'false'; end
  def rs_parse_boolean(v,f); v == 'true'; end

  def rs_format_rss_type(val, fielf)
    vals = val.to_s.split
    if vals.include?('all')
      RssLog.all_types
    else
      RssLog.all_types & vals
    end
  end

  def rs_parse_rss_type(val, field)
    val = ['all']  if val.sort == RssLog.all_types.sort
    val = ['none'] if val.empty?
    val.join(' ')
  end

  def rs_format_stringN(val, field)
    result = []
    if !val.blank?
      search = Query.google_parse(val)
      result += search.bads.map do |x|
        "-#{x}"
      end
      result += search.goods.map do |x|
        x.join(' OR ')
      end
    end
    return result
  end

  def rs_parse_stringN(val, field)
    result = nil
    if val.is_a?(Array)
      result = val.reject(&:blank?).map do |x|
        x = x.dup.strip_squeeze
        if x.sub!(/^-/, '')
          if x.match(/ OR /)
            raise(:runtime_refine_search_bad_google_minus.
                    t(:name => field.name, :value => "-#{x}"))
          end
          x.match(/ /) ? "-\"#{x}\"" : "-#{x}"
        else
          x.split(/ OR /).map do |y|
            if y.match(/^-/)
              raise(:runtime_refine_search_bad_google_minus.
                      t(:name => field.name, :value => "-#{y}"))
            end
            y.match(/ /) ? "\"#{y}\"" : y
          end.join(' OR ')
        end
      end.join(' ')
      result = nil if result.blank?
    end
    return result
  end

  # ----------------------------
  #  Object parsers.
  # ----------------------------

  def rs_format_image(v,f);        rs_format_object(Image,       v,f); end
  def rs_format_location(v,f);     rs_format_object(Location,    v,f); end
  def rs_format_name(v,f);         rs_format_object(Name,        v,f); end
  def rs_format_observation(v,f);  rs_format_object(Observation, v,f); end
  def rs_format_species_list(v,f); rs_format_object(SpeciesList, v,f); end
  def rs_format_user(v,f);         rs_format_object(User,        v,f); end

  def rs_format_location_name(v,f);     rs_format_object(Location,    v,f); end
  def rs_format_name_name(v,f);         rs_format_object(Name,        v,f); end
  def rs_format_species_list_name(v,f); rs_format_object(SpeciesList, v,f); end
  def rs_format_user_name(v,f);         rs_format_object(User,        v,f); end

  def rs_parse_image(v,f);        rs_parse_object(Image,       v,f,1); end
  def rs_parse_location(v,f);     rs_parse_object(Location,    v,f,1); end
  def rs_parse_name(v,f);         rs_parse_object(Name,        v,f,1); end
  def rs_parse_observation(v,f);  rs_parse_object(Observation, v,f,1); end
  def rs_parse_species_list(v,f); rs_parse_object(SpeciesList, v,f,1); end
  def rs_parse_user(v,f);         rs_parse_object(User,        v,f,1); end

  def rs_parse_location_name(v,f);     rs_parse_object(Location,    v,f); end
  def rs_parse_name_name(v,f);         rs_parse_object(Name,        v,f); end
  def rs_parse_species_list_name(v,f); rs_parse_object(SpeciesList, v,f); end
  def rs_parse_user_name(v,f);         rs_parse_object(User,        v,f); end

  def rs_format_imageN(v,f);        rs_format_objectN(Image,       v,f); end
  def rs_format_locationN(v,f);     rs_format_objectN(Location,    v,f); end
  def rs_format_nameN(v,f);         rs_format_objectN(Name,        v,f); end
  def rs_format_observationN(v,f);  rs_format_objectN(Observation, v,f); end
  def rs_format_species_listN(v,f); rs_format_objectN(SpeciesList, v,f); end
  def rs_format_userN(v,f);         rs_format_objectN(User,        v,f); end

  def rs_format_location_nameN(v,f);     rs_format_objectN(Location,    v,f); end
  def rs_format_name_nameN(v,f);         rs_format_objectN(Name,        v,f); end
  def rs_format_species_list_nameN(v,f); rs_format_objectN(SpeciesList, v,f); end
  def rs_format_user_nameN(v,f);         rs_format_objectN(User,        v,f); end

  def rs_parse_imageN(v,f);        rs_parse_objectN(Image,       v,f,1); end
  def rs_parse_locationN(v,f);     rs_parse_objectN(Location,    v,f,1); end
  def rs_parse_nameN(v,f);         rs_parse_objectN(Name,        v,f,1); end
  def rs_parse_observationN(v,f);  rs_parse_objectN(Observation, v,f,1); end
  def rs_parse_species_listN(v,f); rs_parse_objectN(SpeciesList, v,f,1); end
  def rs_parse_userN(v,f);         rs_parse_objectN(User,        v,f,1); end

  def rs_parse_location_nameN(v,f);     rs_parse_objectN(Location,    v,f); end
  def rs_parse_name_nameN(v,f);         rs_parse_objectN(Name,        v,f); end
  def rs_parse_species_list_nameN(v,f); rs_parse_objectN(SpeciesList, v,f); end
  def rs_parse_user_nameN(v,f);         rs_parse_objectN(User,        v,f); end

  def rs_format_object(model, val, field)
    if !val.to_s.match(/^\d+$/)
      val
    elsif obj = model.safe_find(val)
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

  def rs_parse_object(model, val, field, convert=false)
    val = val.strip_squeeze
    if val.blank?
      nil
    elsif val.match(/^\d+$/)
      val
    else
      case model.name
      when 'Location'
        pattern = Query.clean_pattern(Location.clean_name(val, :leave_stars))
        obj = Location.find_by_display_name(val) ||
              Location.first(:conditions => "search_name LIKE '%#{pattern}%'")
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
        error = :runtime_refine_search_object_not_found.t(
          :type => model.type_tag, :field => field.label.t, :value => val
        )
        if convert
          raise(error)
        else
          flash_warning(error)
        end
      end
      convert ? obj.id.to_s : val
    end
  end

  def rs_format_objectN(model, val, field)
    val = [] if val.blank?
    val.map {|v| rs_format_object(model, v, field)}
  end

  def rs_parse_objectN(model, val, field, convert=false)
    result = []
    if !val.blank?
      for val2 in val
        result += val2.to_s.split(/\s+OR\s+/).map do |val3|
          rs_parse_object(model, val3, field, convert)
        end.reject(&:blank?)
      end
    end
    result.empty? ? nil : result
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

  def rs_format_date2(val, field)
    val = [] if val.blank?
    val.map {|v| rs_format_date(v, field)}
  end

  def rs_format_time2(val, field)
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
      nil
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
      nil
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

  def rs_parse_time2(val, field)
    val = [] if val.blank?
    val1 = rs_parse_time(val[0], field)
    val2 = rs_parse_time(val[1], field)
    val2 ? [val1, val2] : val1 ? val1 : nil
  end

  def rs_parse_date2(val, field)
    val = [] if val.blank?
    val1 = rs_parse_date(val[0], field)
    val2 = rs_parse_date(val[1], field)
    val2 ? [val1, val2] : val1 ? val1 : nil
  end

  ##############################################################################
  #
  #  :section: Mechanics
  #
  ##############################################################################

  # Get Array of conditions that the user can use to narrow their search.
  def refine_search_get_fields(query)
    results = []
    model = query.model_symbol
    flavor = query.flavor
    query.parameter_declarations.each do |key, val|
      name = key.to_s.sub(/(\?)$/,'').to_sym
      required = !$1
      if respond_to?("rs_field_#{name}")
        field = send("rs_field_#{name}", model, flavor)
      end
      if field
        field = field.dup
        field.required = required
        field.declare  = val
        results << field
      end
    end
    order = FIELD_ORDER[query.model_symbol]
    results = results.sort_by {|f| f.name.to_s}
    return results.sort_by do |f|
      id = f.id || f.name
      n = order.index(id)
      if !n
        if DEVELOPMENT
          raise("Unordered field #{id.inspect} for #{query.model_symbol}.")
        end
        n = 1000 + results.index(f)
      end
      n
    end
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
      else
        val = val.is_a?(Array) ? val.map(&:to_s) : val.to_s
      end
# flash_notice("init: name=#{field.name} default=#{field.default.inspect} from=#{query.params[field.name].inspect} to=#{val.inspect}")
      if field.input.to_s.match(/(\d+|N)$/)
        n = ($1 != 'N') ? $1.to_i :
            (val.is_a?(Array) && val.length > 0) ? val.length + 1 : 1
        field.num = n
        values.send("#{field.name}_n=", n)
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
        val = field.default if val.nil?
        if val.nil? && field.required
          flash_error(:runtime_refine_search_field_required.t(:field =>
                                                              field.label))
          errors << field.name
        end
      rescue => e
        flash_error(e)
        # flash_error(e.backtrace.join("<br>"))
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
    if field.input == :checkboxes
      result = []
      for label, val in field.opts
        if values.send("#{field.name}_#{val}") == '1'
          result << val
        end
      end
    elsif field.input.to_s.match(/(\d+|N)$/)
      n = ($1 != 'N') ? $1.to_i : values.send("#{field.name}_n").to_i
      n = 1 if n.blank? || n == 0
      result = []
      for i in 1..n
        result << refine_search_get_value(field, values, i)
      end
    else
      result = refine_search_get_value(field, values)
    end
    if !result.blank?
      case field.parse
      when Symbol
        result = send("rs_parse_#{field.parse}", result, field)
      when Proc
        result = field.parse.call(result, field)
      else
        if result.is_a?(Array)
          while result.length > 0 && result.last.blank?
            result.pop
          end
          result = nil if result.empty?
        end
      end
    else
      result = nil
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
      :input => :menu,
      :opts  => menu,
      :required => true
    )
  end
end
