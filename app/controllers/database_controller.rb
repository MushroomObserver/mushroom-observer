################################################################################
#
#  This controller handles the XML database interface.
#
#  Views:
#    comments
#    images
#    locations
#    names
#    observations
#    users
#
#  Helpers:
#    authenticate               Check user's authentication.
#    parse_param(name)          Pull parameter out of request if given
#    error_if_any_other_params  Raise errors for all unused parameters.
#
#  Error codes:
#    101 - 'bad request type'
#    102 - 'bad request syntax'
#    201 - 'object not found'
#    301 - 'authentication failed'
#    501 - 'internal error'
#
################################################################################

class DatabaseController < ApplicationController

  def comments;     general_query(:comment);     end
  def images;       general_query(:image);       end
  def locations;    general_query(:location);    end
  def names;        general_query(:name);        end
  def observations; general_query(:observation); end
  def users;        general_query(:user);        end

  def general_query(type)
    @start_time = Time.now
    @errors = []
    @objects = []

    # Converts :species_list to the class SpeciesList.
    model = type.to_s.camelize.constantize
    table = type.to_s.pluralize

    begin
      case request.method

      # Query existing objects.
      when :get
        raise error(101, "GET method not available for #{type}.") if !respond_to?("get_#{type}")
        conds, tables, joins, max_num_per_page = send("get_#{type}")
        @page = parse_page
        num_per_page = parse_num_per_page(max_num_per_page)
        error_if_any_other_params

        tables.unshift(table)
        tables = "FROM #{tables.join(', ')}"
        conds  = "WHERE #{conds.join(' AND ')}"
        conds  = '' if conds == 'WHERE '
        limit  = "LIMIT #{(@page-1)*num_per_page}, #{num_per_page}"
        count_query = "SELECT COUNT(DISTINCT #{table}.id) #{tables} #{conds}"
        @query = "SELECT DISTINCT #{table}.id #{tables} #{conds} #{limit}"
        @number = model.connection.select_value(count_query).to_i
        @pages = (@number.to_f / num_per_page).ceil
        ids = model.connection.select_values(@query)
        @objects = model.all(
          :include => joins,
          :conditions => ['id in (?)', ids]
        )

      # Post new object.
      when :post :
        raise error(101, "POST method not yet available for #{type}s.") if !respond_to?("post_#{type}")
        authenticate
        send("post_#{type}")

      # Update existing object.
      when :put :
        raise error(101, "PUT method not yet available for #{type}s.") if !respond_to?("put_#{type}")
        authenticate
        conds = parse_id(:id, :id)
        raise error(201, "must specify id(s)") if !conds
        query = "SELECT DISTINCT id FROM #{table} WHERE #{conds}"
        ids = model.connection.select_values(query)
        make_sure_found_all_objects(ids, type)
        @objects = model.all(:conditions => ['id in (?)', ids])
        send("put_#{type}", ids)

      # Delete object.
      when :delete :
        raise error(101, "DELETE method not yet available for #{type}s.") if !respond_to?("delete_#{type}")
        authenticate
        conds = parse_id(:id, :id)
        raise error(201, "must specify id(s)") if !conds
        query = "SELECT DISTINCT id FROM #{table} WHERE #{conds}"
        ids = model.connection.select_values(query)
        make_sure_found_all_objects(ids, type)
        @objects = model.all(:conditions => ['id in (?)', ids])
        send("delete_#{type}", ids)

      else
        raise error(101, "invalid request method: '#{request.method}' (expect 'GET' or 'POST'")
      end
    rescue => e
      if !e.is_a?(MoApiException)
        s = e.to_s
        s += "\n" + e.backtrace.join("\n") if !s.match(/\n.*\n.*\n/)
        e = error(501, s, true)
      else
        e.fatal = true
      end
      @errors << e
    end

    begin
      render(:layout => 'database')
    rescue => e
      if !e.is_a?(MoApiException)
        s = e.to_s
        s += "\n" + e.backtrace.join("\n") if !s.match(/\n.*\n.*\n/)
        e = error(501, s, true)
      else
        e.fatal = true
      end
      @errors << e
      render(:text => '', :layout => 'database')
    end
  end

################################################################################

  def get_comment
    conds = []
    tables = []
    joins = [:user]

    conds += parse_id(:id, 'comments.id')
    conds += parse_id_or_name(:user, 'comments.user_id', 'users.login', 'users.name')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = comments.user_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_image
    conds = []
    tables = []
    joins = [:user, :license]

    conds += parse_id(:id, 'images.id')
    conds += parse_id_or_name(:user, 'images.user_id', 'users.login', 'users.name')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = images.user_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_location
    conds = []
    tables = []
    joins = []

    conds += parse_id(:id, 'locations.id')

    return [conds, tables, joins, 1000]
  end

  def get_name
    conds = []
    tables = []
    joins = [{:synonym => :names}]

    conds += parse_id(:id, 'names.id')

    return [conds, tables, joins, 1000]
  end

  def get_observation
    conds = []
    tables = []
    joins = [
      :user,
      :location,
      {:name => {:synonym => :names}},
      {:namings => :name},
      {:images => [:user, :license]},
      {:comments => :user}
    ]

    conds += parse_id(:id, 'observations.id')
    conds += parse_date(:date, 'observations.when')
    conds += parse_id_or_name(:user, 'observations.user_id', 'users.login', 'users.name')
    conds += parse_id_or_name(:name, 'observations.name_id', 'names.text_name', 'names.search_name')
    conds += parse_id_or_name(:location, 'observations.location_id', 'observations.where', 'locations.name')
    conds += parse_search(:notes, 'observations.notes')
    conds << 'observations.thumb_image_id NOT NULL' if parse_param(:has_image)
    conds << 'observations.specimen = TRUE'         if parse_param(:has_specimen)

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = observations.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      conds << 'names.id = observations.name_id'
    end
    if uses_table?(conds, 'locations')
      tables << :locations
      conds << 'locations.id = observations.location_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_user
    conds = []
    tables = []
    joins = [:location, :image]

    conds += parse_id(:id, 'users.id')

    return [conds, tables, joins, 1000]
  end

################################################################################

  # Check user's authentication.
  def authenticate
    result = nil
    auth_id   = parse_param(:auth_id)
    auth_code = parse_param(:auth_code)
    begin
      user = User.find(auth_id.to_i)
      if user.auth_code == auth_code
        result = user
      else
        raise error(301, "invalid auth_code: '#{auth_code}'")
      end
    rescue
      raise error(301, "invalid auth_id: '#{auth_id}'")
    end
    return result
  end

  def error(code, msg, fatal=false)
    MoApiException.new(
      :code  => code,
      :msg   => msg,
      :fatal => fatal
    )
  end

  # Pull parameter out of request if given.
  def parse_param(name)
    @used ||= {}
    result = nil
    if params[name].to_s != ''
      @used[name.to_s] = true
      result = params[name]
    end
    # Save this for error checking later (see make_sure_found_all_objects).
    @ids_param = result if name == :id
    return result
  end

  # Raise errors for all unused parameters.
  def error_if_any_other_params
    @used['controller'] = true
    @used['action'] = true
    for key in params.keys
      if !@used[key.to_s]
        @errors << error(102, "unrecognized argument: '#{key}' (ignored)")
      end
    end
  end

  # Check that objects were found for all the given ids.  (It uses the "global"
  # @ids_param to get a list of all the requested ids.  It expects every id
  # listed individually to exist, and at least one id inside each range.)
  def make_sure_found_all_objects(ids, type)
    if @ids_param
      for x in @ids_param.split(',')
        if x.match(/^\d+$/)
          if !ids.include?(x.to_i)
            @errors << error(201, "#{type} ##{a} not found")
          end
        elsif x.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          a, b = b, a if a > b
          if !ids.any? {|x| x >= a || x <= b}
            @errors << error(201, "no #{type} found between ##{a} and ##{b}")
          end
        end
      end
    end
  end

  # Get page number from parameters.
  def parse_page
    result = nil
    if x = parse_param(:page)
      result = x.to_i
      raise error(102, "invalid page: '#{x}'") if result < 1
    else
      result = 1
    end
    return result
  end

  # Get page length from parameters.
  def parse_num_per_page(max)
    result = nil
    if x = parse_param(:num_per_page)
      result = x.to_i
      raise error(102, "invalid num_per_page: '#{x}'") if result < 1
      raise error(102, "num_per_page too large: '#{x}' (max is #{max})") if result > max
    else
      result = max/10
    end
    return result
  end

  # Parse an id parameter and build an SQL condition to process it.
  # Valid syntaxes:
  #   n
  #   m-n
  #   a,b,c-d,...
  def parse_id(arg, column)
    result = []
    if x = parse_param(arg)

      # Parse string into comma-delimited numbers and "m-n" ranges.
      singles = []
      ranges  = []
      for y in x.split(',')
        if y.match(/^\d+$/)
          a = y.to_i
          if a < 1 || a > 1e9
            raise error(102, "#{arg} out of range: '#{a}'")
          else
            singles << a
          end
        elsif y.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          a, b = b, a if a > b
          if a < 1 || a > 1e9
            raise error(102, "#{arg} out of range: '#{a}'")
          elsif b < 1 || b > 1e9
            raise error(102, "#{arg} out of range: '#{b}'")
          elsif b - a > 1e6
            raise error(102, "#{arg} range too large: '#{a}-#{b}' (max is 1000000)")
          elsif b - a > 10
            ranges << (a..b)
          else
            singles += (a..b).to_a
          end
        else
          raise error(102, "invalid #{arg}: '#{y}'")
        end
      end

      # Combine the "blah IN (set)" and "blah BETWEEN a AND b" clauses.
      ors = []
      ors << build_sql(["#{column} IN (?)", singles]) if !singles.empty?
      for range in ranges
        ors << build_sql(["#{column} BETWEEN ? AND ?", range.begin, range.end])
      end
      result << '(' + ors.join(' OR ') + ')'

    end
    return result
  end

  # Parse an id/name parameter and build an SQL condition to process it.
  # Valid syntaxes:
  #   a,b,c-d,...
  #      OR
  #   name1,name2,...
  def parse_id_or_name(arg, id_column, *name_columns)
    result = []
    if x = parse_param(arg)
      if x.match(/^[\d\-\,]*$/)
        result += parse_id(arg, id_column)
      else
        ors = []
        for y in x.split(',')
          for col in name_columns
            ors << build_sql(["#{col} = ?", y])
          end
        end
        result << '(' + ors.join(' OR ') + ')'
      end
    end
    return result
  end

  # Parse date parameter and build an SQL condition to process it.
  # Valid syntaxes:
  #   
  def parse_date(arg, column)
    result = []
    if x = parse_param(arg)
      if x.match(/^\d\d\d\d-?\d\d-?\d\d$/)
        y = Date.parse(x)
        result << build_sql(["#{column} = ?", y])
      else
        raise error(102, "invalid #{arg}: '#{x}' (expect 'YYYY-MM-DD')")
      end
    end
    return result
  end

  # Parse text-search parameter and build an SQL condition to process it.
  # Valid syntaxes:
  #   string
  def parse_search(arg, *columns)
    result = []
    if x = parse_param(:notes)
      for col in columns
        result << build_sql(["#{col} LIKE ?", "%#{x}%"]) 
      end
    end
    return result
  end

  # Check if list of conditions uses a given table.
  def uses_table?(conds, table)
    result = false
    for cond in conds
      if cond.include?("#{table}.")
        result = true
        break
      end
    end
    return result
  end

  # Short-hand method of calling the handy (but protected) sanitize_sql_array
  # method in ActiveRecord.
  def build_sql(*args)
    ActiveRecord::Base.sanitize_sql_array_public(*args)
  end
end

module ActiveRecord
  class Base
    class << self
      # The blasted thing is protected, so I have to create a public wrapper...
      def sanitize_sql_array_public(*args)
        sanitize_sql_array(*args)
      end
    end
  end
end
