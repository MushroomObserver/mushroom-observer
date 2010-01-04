################################################################################
#
#  This controller handles the XML interface.
#
#  All request types use a single URL for each object class.  Thus, searching
#  for, updating, destroying, and creating observations use:
#
#    GET    http://mo.org/api/observations       Search for observations.
#    PUT    http://mo.org/api/observations       Modify observations.
#    DELETE http://mo.org/api/observations       Destroy observations.
#    POST   http://mo.org/api/observations       Create a new observation.
#
#  GET, PUT and DELETE requests all take the same "search" parameters, e.g.:
#
#    GET http://mo.org/api/observations/12345
#    GET http://mo.org/api/observations?user=jason
#    GET http://mo.org/api/observations?date=20090101-20100101
#
#  GET requests return information about matching objects.  DELETE requests
#  attempt to destroy all matching objects.  PUT requests allow users to make
#  one or more changes to all matching objects.  Changes are specified with
#  "set" parameters, e.g.:
#
#    PUT http://mo.org/api/observations/12345?set_date=20090731
#    PUT http://mo.org/api/observations?user=jason&date=20091201&set_specimen=true
#
#  (The former changes the date on observation #12345; the latter informs MO
#  that specimens are available for all of Jason's observations on 20091201.)
#
#  POST requests attempt to create a new object and return the same information
#  a GET request of that single id would return (or an error message).
#
#  Only certain request types are allowed for certain objects.  This is
#  determined by the presence of methods called "get_user", "delete_name",
#  "put_observation", "post_comment", etc.  The calling syntax for each is
#  described below.
#
#  The "get_xxx" methods are responsible for parsing the "search" parameters
#  and returning enough information to create a SQL query:
#
#    conditions,
#    tables,
#    joins,
#    max_num_per_page =
#      get_observation()
#
#  The "put_xxx" methods are responsible for parsing the "set" parameters and
#  returning a hash that will be passed into object.write_attributes:
#
#    assigns =
#      put_observation()
#
#  The "delete_xxx" methods do nothing.  They are never called; it's only
#  important that they *exist*.
#
#  The "post_xxx" methods parse the necessary arguments, create the object,
#  and return the resulting object.  They raise errors if anything goes wrong.
#
#  Views:
#    comments
#    images
#    licenses
#    locations
#    names
#    observations
#    users
#
#  "Magic" methods: (see above)
#    get_<type>             Parse search parameters for GET/PUT/DELETE requests.
#    put_<type>             Parse set_xxx parameters for PUT requests.
#    delete_<type>          Never called; enables DELETE if present.
#    post_<type>            Create and return new object.
#
#  Helpers:
#    authenticate               Check user's authentication.
#    parse_param(name)          Pull parameter out of request if given
#    error_if_any_other_params  Raise errors for all unused parameters.
#
#  Error codes: (see api_helper.rb and schema.xsd, too)
#    101 - 'bad request type'
#    102 - 'bad request syntax'
#    201 - 'object not found'
#    202 - 'failed to create object'
#    203 - 'failed to update object'
#    204 - 'failed to delete object'
#    301 - 'authentication failed'
#    302 - 'permission denied'
#    501 - 'internal error'
#
################################################################################

class ApiController < ApplicationController

  def comments;     general_query(:comment);     end
  def images;       general_query(:image);       end
  def licenses;     general_query(:license);     end
  def locations;    general_query(:location);    end
  def names;        general_query(:name);        end
  def namings;      general_query(:naming);      end
  def observations; general_query(:observation); end
  def users;        general_query(:user);        end
  def votes;        general_query(:vote);        end

  def general_query(type)
    @start_time = Time.now
    @errors = []
    @objects = []

    # Converts :species_list to the class SpeciesList.
    model = type.to_s.camelize.constantize
    table = type.to_s.pluralize

    begin
      case method = request.method

      # Create new object.
      when :post :
        raise error(101, "POST method not yet available for #{type}s.") if !respond_to?("post_#{type}")
        @user = authenticate
        if result = send("post_#{type}")
          @objects << result
        end

      # Lookup, update or delete existing objects.
      when :get, :put, :delete
        raise error(101, "#{method.to_s.upcase} method not available for #{type}.") \
          if !respond_to?("#{method}_#{type}")

        # First parse query parameters.
        conds, tables, joins, max_num_per_page = send("get_#{type}")

        # Allow GET to paginate.
        if method == :get
          @page = parse_page
          num_per_page = parse_num_per_page(max_num_per_page)
        else
          @page = nil
          num_per_page = nil
        end

        # Get array of values to change for PUT.
        if method == :put
          sets = send("put_#{type}")
          if sets.is_a?(Hash) && sets.empty?
            raise error(102, "you didn't specify any values to change")
          end
        end

        # Authenticate user for PUT and DELETE.
        if method != :get
          @user = authenticate
        end

        # No other parameters are allowed.
        error_if_any_other_params

        # Create lookup query.
        tables.unshift(table)
        tables = "FROM #{tables.join(', ')}"
        conds  = "WHERE #{conds.join(' AND ')}"
        conds  = '' if conds == 'WHERE '
        limit  = @page ? "LIMIT #{(@page-1)*num_per_page}, #{num_per_page}" : ''
        count_query = "SELECT COUNT(DISTINCT #{table}.id) #{tables} #{conds}"
        @query = "SELECT DISTINCT #{table}.id #{tables} #{conds} #{limit}"

        # Count total number of hits for GET.
        if method == :get
          @number = model.connection.select_value(count_query).to_i
          @pages = (@number.to_f / num_per_page).ceil
        end

        # Lookup ids using our SQL query.
        ids = model.connection.select_values(@query)
        make_sure_found_all_objects(ids, type)

        # Now let ActiveRecord load full objects (with eager-loading for GET).
        if method == :get
          @objects = model.all(:conditions => ['id in (?)', ids], :include => joins)
        else
          @objects = model.all(:conditions => ['id in (?)', ids])
        end

        # Apply updates to all matching objects... carefully.
        if method == :put
          @objects.each do |x|
            id = x.id
            begin
              if x.user != @user
                @errors << error(302, "only owner may modify #{type} ##{id}")
              elsif !(sets.is_a?(Proc) ? sets.call(x) : x.update_attributes(sets))
                @errors << error(203, "failed to update #{type} ##{id}:\n#{x.formatted_errors}")
              end
            rescue => e
              @errors << convert_error(e, 203, "error occurred while updating #{type} ##{id}")
            end
          end

        # Delete matching objects... carefully.
        elsif method == :delete
          @objects.each do |x|
            id = x.id
            begin
              if x.user != @user
                @errors << error(302, "only owner may destroy #{type} ##{id}")
              elsif !send("delete_#{type}", x)
                @errors << error(204, "failed to destroy #{type} ##{id}:\n#{x.formatted_errors}")
              end
            rescue => e
              @errors << convert_error(e, 204, "error occurred while destroying #{type} ##{id}")
            end
          end
        end

      else
        raise error(101, "invalid request method: '#{request.method}' (expect 'GET' or 'POST'")
      end
    rescue => e
      e = convert_error(e, 501, nil, true)
      e.fatal = true
      @errors << e
    end

    begin
      if [:get, :post].include?(request.method)
        render(:layout => 'api')
      else
        render(:layout => 'api', :text => '')
      end
    rescue => e
      e = convert_error(e, 501, nil, true)
      e.fatal = true
      @errors << e
      render(:layout => 'api', :text => '')
    end
  end

################################################################################

  def get_comment
    conds = []
    tables = []
    joins = [:user]

    conds += parse_id_or_name(:user, 'comments.user_id', 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'comments.id')

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

    conds += parse_id_or_name(:user, 'images.user_id', 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'images.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = images.user_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_license
    conds = []
    tables = []
    joins = []

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'licenses.id')

    return [conds, tables, joins, 1000]
  end

  def get_location
    conds = []
    tables = []
    joins = []

    conds += parse_id_or_name(:user, 'locations.user_id', 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'locations.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = locations.user_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_name
    conds = []
    tables = []
    joins = [{:synonym => :names}]

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'names.id')

    return [conds, tables, joins, 1000]
  end

  def get_naming
    conds = []
    tables = []
    joins = [:user, :observation, :name, :naming_reasons, :votes]

    conds += parse_id(:observation, 'namings.observation_id')
    conds += parse_id_or_name(:user, 'namings.user_id', 'users.login', 'users.name')
    conds += parse_id_or_name(:name, 'namings.name_id', 'names.text_name', 'names.search_name')

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'namings.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = namings.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      conds << 'names.id = namings.name_id'
    end

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

    conds += parse_date(:date, 'observations.when')
    conds += parse_id_or_name(:user, 'observations.user_id', 'users.login', 'users.name')
    conds += parse_id_or_name(:name, 'observations.name_id', 'names.text_name', 'names.search_name')
    conds += parse_id_or_name(:location, 'observations.location_id', 'observations.where', 'locations.name')
    conds += parse_search(:notes, 'observations.notes')
    conds << 'observations.thumb_image_id NOT NULL' if parse_param(:has_image)
    conds << 'observations.specimen = TRUE'         if parse_param(:has_specimen)

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'observations.id')

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

    conds += parse_search(:name, 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'users.id')

    return [conds, tables, joins, 1000]
  end

  def get_vote
    conds = []
    tables = []
    joins = []

    @something_besides_ids = true if !conds.empty?
    conds += parse_id(:id, 'votes.id')

    return [conds, tables, joins, 10000]
  end

################################################################################

  def put_comment
    sets = {}
    sets[:summary] = x if x = parse_set_string(:set_summary, 100)
    sets[:content] = x if x = parse_set_string(:set_content)
    return sets
  end

  def put_image
    sets = {}
    sets[:date]             = x if x = parse_set_date(:set_date)
    sets[:notes]            = x if x = parse_set_string(:set_notes)
    sets[:copyright_holder] = x if x = parse_set_string(:set_copyright_holder, 100)
    sets[:license]          = x if x = parse_set_object(:set_license, License)
    return sets
  end

  # def put_location
  #   TODO
  # end

  # def put_name
  #   TODO
  # end

  def put_naming
    sets = {}
    sets[:name]        = x if x = parse_set_object(:set_name, Name)
    sets[:by_sight]    = x if x = parse_set_string(:set_by_sight)
    sets[:used_refs]   = x if x = parse_set_string(:set_used_refs)
    sets[:microscopic] = x if x = parse_set_string(:set_microscopic)
    sets[:chemical]    = x if x = parse_set_string(:set_chemical)

    # Changing name and/or reasons is non-trivial.
    if !sets.empty?
      vals = sets
      sets = lambda do |naming|

        # Change name.
        if (new_name = vals[:name]) && (naming.name != new_name)
          if naming.observation.name_been_proposed?(new_name)
            @errors << error(203, "name #{new_name.id} has already been proposed (naming ##{naming.id})")
          elsif !naming.editable?
            @errors << error(203, "not allowed to change naming ##{naming.id} since at least one other user has given it a positive vote")
          else
            if update_naming_object(naming, new_name, true)
              # Invalidate votes if name changed.
              for vote in naming.votes
                vote.destroy if vote.user_id != @user.id
              end
              naming.observation.reload
              naming.observation.calc_consensus(@user)
            end
          end
        end

        # Update reasons.
        nrs = naming.naming_reasons
        i = 1
        for x in [:by_sight, :used_refs, :microscopic, :chemical]
          v = vals[x]
          need_to_create = true
          for nr in nrs
            if nr.reason == i
              if v == 'delete'
                # Destroy reason.
                nr.destroy
              else
                # Change existing reason.
                nr.notes = v
                nr.save
              end
              need_to_create = false
              break
            end
          end
          if need_to_create
            # Create new reason.
            nr = NamingReason.new(:naming => naming, :reason => i, :notes => v)
            nr.save
          end
          i += 1
        end
      end
    end

    return sets
  end

  def put_observation
    sets = {}
    if x = parse_set_object(:set_location, Location)
      sets[:location] = x
      sets[:where]    = nil
    end
    sets[:date]                   = x if x = parse_set_date(:set_date)
    sets[:notes]                  = x if x = parse_set_string(:set_notes)
    sets[:thumbnail]              = x if x = parse_set_object(:set_thumbnail, Image)
    sets[:specimen]               = x if x = parse_set_boolean(:set_specimen)
    sets[:is_collection_location] = x if x = parse_set_boolean(:set_is_collection_location)
    return sets
  end

  # def put_user
  #   TODO
  # end

  def put_vote
    sets = {}
    if val = parse_set_vote(:set_value)
      # Return a proc that changes the vote.
      sets = lambda do |vote|
        result = false
        if vote.value == val
          # Return "trivial" true if value is already correct.
          result = true
        else
          # Otherwise return true if vote is successfully changed.
          result = vote.naming.change_vote(@user, val)
        end
        return result
      end
    end
    return sets
  end

################################################################################

  def delete_comment(comment)
    return comment.destroy(@user)
  end

  def delete_image(image)
    return image.destroy(@user)
  end

  def delete_naming(naming)
    result = false
    if !naming.deletable?
      @errors << error(204, "not allowed to delete naming ##{naming.id} from observation ##{naming.observation_id}")
    elsif !naming.destroy(@user)
      @errors << error(204, "failed to delete naming ##{naming.id} from observation ##{naming.observation_id}")
    else
      result = true
    end
    return result
  end

  def delete_observation(observation)
    return observation.destroy(@user)
  end

  def delete_vote(vote)
    result = false
    if vote.naming.user == @user
      @errors << error(204, "cannot delete your vote (##{vote.id}) on your own naming (##{vote.naming_id})")
    else
      result = vote.naming.change_vote(@user, Vote.delete_vote)
    end
    return result
  end

################################################################################

  def post_comment
    summary = parse_set_string(:summary, 100)
    content = parse_set_string(:content)
    object  = parse_set_object(:observation, Observation)

    summary ||= '.'
    content ||= ''

    raise error(102, 'missing content') if !content
    raise error(102, 'missing object')  if !object

    comment = Comment.new(
      :created => Time.now,
      :user    => @user,
      :summary => summary,
      :content => content,
      :object  => object
    )
    raise error(202, comment.formatted_errors) if !comment.save
    object.log(:log_comment_added, { :user => @user.login,
      :summary => summary }, true) \
      if object.respond_to?(:log)
    return comment
  end

  def post_image
    temp = nil

    now              = Time.now
    url              = parse_set_string(:url)
    file             = parse_set_string(:file)
    date             = parse_set_date(:date)
    notes            = parse_set_string(:notes)
    copyright_holder = parse_set_string(:copyright_holder, 100)
    license          = parse_set_object(:license, License)
    observation      = parse_set_object(:observation, Observation)

    date             ||= observation.when if observation
    notes            ||= ''
    copyright_holder ||= @user.legal_name
    license          ||= @user.license

    raise error(102, 'missing date') if !date
    raise error(102, 'cannot use both url and file') if url && file
    raise error(102, 'only jason can use file') if file && @user.login != 'jason'
    raise error(102, 'expected file to be "name.jpg"') if file && !file.match(/^[\w\.\-]+\.jpg$/)

    if url
      temp, header   = load_from_url(url)
      io             = File.open(temp, 'r')
      content_length = header['Content-Length']
      content_type   = header['Content-Type']
      content_md5    = header['Content-MD5']
    elsif file
      file           = "/home/jason/images/#{file}"
      io             = File.open(file, 'r')
      content_length = File.size(file)
      content_type   = 'image/jpeg'
    else
      io             = request.body
      content_length = request.content_length
      content_type   = request.content_type
      content_md5    = request.headers['Content-MD5']
    end

    image = Image.new(
      :created          => now,
      :modified         => now,
      :user             => @user,
      :when             => date,
      :notes            => notes,
      :copyright_holder => copyright_holder,
      :license          => license,
      :image            => io,
      :content_length   => content_length,
      :content_type     => content_type,
      :content_md5      => content_md5
    )
    raise error(202, image.formatted_errors) if !image.save || !image.save_image
    observation.add_image_with_log(image, @user) if observation
    return image

  ensure
    # Make sure the temp file is deleted.
    File.delete(temp) if temp
  end

  def post_location
    now   = Time.now
    name  = parse_set_string(:name, 200)
    notes = parse_set_string(:notes)
    north = parse_set_float(:north)
    south = parse_set_float(:south)
    east  = parse_set_float(:east)
    west  = parse_set_float(:west)
    high  = parse_set_float(:high)
    low   = parse_set_float(:low)

    notes ||= ''

    raise error(102, 'missing name')  if !name
    raise error(102, 'missing north') if !north
    raise error(102, 'missing south') if !south
    raise error(102, 'missing east')  if !east
    raise error(102, 'missing west')  if !west
    raise error(102, 'missing high')  if !high
    raise error(102, 'missing low')   if !low

    location = Location.new(
      :created          => now,
      :modified         => now,
      :user             => @user,
      :display_name     => name,
      :notes            => notes,
      :north            => north,
      :south            => south,
      :east             => east,
      :west             => west,
      :high             => high,
      :low              => low
    )
    raise error(202, location.formatted_errors) if !location.save
    return location
  end

  def post_name
    rank       = parse_set_rank(:rank)
    name_str   = parse_set_string(:name, 100)
    author     = parse_set_string(:author, 100)
    citation   = parse_set_string(:citation)
    deprecated = parse_set_boolean(:deprecated)
    notes      = {}
    for f in Name.all_note_fields
      notes[f] = parse_set_string(f)
    end

    raise error(102, 'missing rank') if !rank
    raise error(102, 'missing name') if !name_str

    # Make sure name doesn't already exist.
    match = nil
    if author && author != ''
      match = Name.find_by_text_name_and_author(name_str, author)
      name_str2 = "#{name_str} #{author}"
    else
      match = Name.find_by_text_name(name_str)
      name_str2 = name_str
    end
    raise error(202, "name already exists") if match

    # Make sure the name parses.
    names = Name.names_from_string(name_str2)
    name = names.last
    raise error(202, "invalid name") if name.nil?

    # Fill in information.
    name.rank = rank
    name.citation = citation
    name.change_text_name(name_str, author, rank)
    name.change_deprecated(true) if deprecated
    for f in notes.keys
      name.send("#{f}=", notes[f])
    end

    # Save it and any implictly-created parents (e.g. genus when creating
    # species for unrecognized genus).
    for name in names
      if name
        name.user = @user
        name.save
        name.add_editor(@user)
      end
    end
    return names.last
  end

  def post_naming
    now         = Time.now
    name        = parse_set_object(:name, Name)
    observation = parse_set_object(:observation, Observation)
    vote        = parse_set_vote(:vote)
    by_sight    = parse_set_string(:by_sight)
    used_refs   = parse_set_string(:used_refs)
    microscopic = parse_set_string(:microscopic)
    chemical    = parse_set_string(:chemical)

    raise error(102, 'missing name')        if !name
    raise error(102, 'missing observation') if !observation
    raise error(102, 'missing vote')        if !vote

    naming = Naming.new(
      :created     => now,
      :modified    => now,
      :observation => observation,
      :name        => name,
      :user        => @user
    )
    raise error(202, naming.formatted_errors) if !naming.save

    # Attach vote.
    naming.change_vote(@user, vote)

    # Attach reasons.
    i = 1
    for x in [by_sight, used_refs, microscopic, chemical]
      if x
        nr = NamingReason.new(:naming => naming, :reason => i, :notes => x)
        nr.save
      end
      i += 1
    end

    return naming
  end

  def post_observation
    now                    = Time.now
    date                   = parse_set_date(:date)
    location               = parse_set_object(:location, Location)
    specimen               = parse_set_boolean(:specimen)
    is_collection_location = parse_set_boolean(:is_collection_location)
    notes                  = parse_set_string(:notes)
    thumbnail              = parse_set_object(:thumbnail, Image)
    images                 = parse_set_objects(:images, Image)

    date                   ||= now
    location               ||= @user.location
    is_collection_location ||= true
    notes                  ||= ''

    raise error(102, 'missing location') if !location

    obs = Observation.new(
      :created                => now,
      :modified               => now,
      :when                   => date,
      :user                   => @user,
      :location               => location,
      :specimen               => specimen,
      :is_collection_location => is_collection_location,
      :notes                  => notes,
      :thumbnail_image        => thumbnail
    )
    raise error(202, obs.formatted_errors) if !obs.save
    obs.log(:log_observation_created, { :user => @user.login }, true)
    obs.images += images if !images.empty?
    return obs
  end

  def post_vote
    naming = parse_set_object(:naming, Naming)
    value  = parse_set_vote(:value)

    raise error(102, 'missing naming') if !naming
    raise error(102, 'missing vote')   if !vote

    naming.change_vote(@user, vote)
    return Vote.find_by_user_and_naming(@user, naming)
  end

################################################################################

  # Check user's authentication.
  def authenticate
    result = nil
    auth_id   = parse_param(:auth_id)
    auth_code = parse_param(:auth_code)
    begin
      user = User.find(auth_id.to_i)
    rescue
      raise error(301, "invalid auth_id: '#{auth_id}'")
    end
    if user.auth_code == auth_code
      result = user
    else
      raise error(301, "invalid auth_code: '#{auth_code}'")
    end
    return result
  end

  # Create an MoApiException.
  def error(code, msg, fatal=false)
    MoApiException.new(
      :code  => code,
      :msg   => msg,
      :fatal => fatal
    )
  end

  # Make sure the given exception is an MoApiException.  If not, wrap it in an
  # MoApiException so that all errors are of the same type.
  def convert_error(e, code, msg, *args)
    if !e.is_a?(MoApiException)
      s = e.to_s
      s += "\n" + e.backtrace.join("\n") if !s.match(/\n.*\n.*\n/)
      s = "#{msg}: #{s}" if msg
      e = error(code, s, *args)
    end
    return e
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

  # Check that objects were found for all the given ids.  (It uses the
  # "globals" @ids_param and @something_besides_ids: the former is a list of
  # all the requested ids; the latter tells us if the search was futher refined
  # from the list of ids.  It expects every id listed individually to exist,
  # and at least one id to exist inside each range.  But only if there are no
  # restrictions besides ids.)
  def make_sure_found_all_objects(ids, type)
    if @ids_param && !@something_besides_ids
      for x in @ids_param.split(',')
        if x.match(/^\d+$/)
          if !ids.include?(x.to_s) && !ids.include?(x.to_i)
            @errors << error(201, "#{type} ##{x} not found")
          end
        elsif x.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          a, b = b, a if a > b
          if !ids.any? {|x| x.to_i >= a || x.to_i <= b}
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

  # Parse and validate a boolean.
  def parse_set_boolean(arg)
    result = nil
    if x = parse_param(arg)
      if x == '0' || x.downcase == 'false'
        result = false
      elsif x == '1' || x.downcase == 'true'
        result = true
      else
        raise error(102, "#{arg} should be 'true'/'false' or '1'/'0'")
      end
    end
    return result
  end

  # Parse and validate an integer.
  def parse_set_integer(arg)
    result = nil
    if x = parse_param(arg)
      if x.match(/^-?\d+$/)
        result = x.to_i
      else
        raise error(102, "#{arg} must be an integer")
      end
    end
    return result
  end

  # Parse and validate an integer.
  def parse_set_float(arg)
    result = nil
    if x = parse_param(arg)
      if x.match(/^-?(\d*\.\d+|\d+)$/)
        result = x.to_f
      else
        raise error(102, "#{arg} must be a floating-point")
      end
    end
    return result
  end

  # Parse and validate a vote (integer between 0 and 100).
  def parse_set_vote(arg)
    result = nil
    if x = parse_param(arg)
      if x.match(/^\d+$/) && x.to_i <= 100
        result = x.to_f / 100 * (Vote.maximum - Vote.minimum) + Vote.minimum
      else
        raise error(102, "#{arg} must be an integer between 0 and 100")
      end
    end
    return result
  end

  # Parse and validate a string.
  def parse_set_string(arg, length=nil)
    result = nil
    if x = parse_param(arg)
      if !length || x.length <= length
        result = x
      else
        raise error(102, "#{arg} must be #{length} characters or less")
      end
    end
    return result
  end

  # Parse and validate a date.
  def parse_set_date(arg)
    result = nil
    if x = parse_param(arg)
      if x.match(/^\d\d\d\d-?\d\d-?\d\d$/)
        result = Date.parse(x)
      else
        raise error(102, "#{arg} must be 'YYYY-MM-DD'")
      end
    end
    return result
  end

  # Parse and validate an object id.
  def parse_set_object(arg, model)
    result = nil
    if x = parse_param(arg)
      if x.match(/^\d+$/)
        begin
          result = model.find(x.to_i)
        rescue
          raise error(102, "#{arg}=#{x} was not found")
        end
      else
        raise error(102, "#{arg} must be integer id")
      end
    end
    return result
  end

  # Parse and validate a list of object ids.
  def parse_set_objects(arg, model)
    result = []
    if x = parse_param(arg)
      for y in x.split(',')
        if y.match(/^\d+$/)
          begin
            result << model.find(y.to_i)
          rescue
            raise error(102, "#{arg}=#{y} was not found")
          end
        else
          raise error(102, "#{arg} must be comma-separated list of integer ids")
        end
      end
    end
    return result
  end

  # Parse and validate a rank (enumerated string).
  def parse_set_rank(arg)
    result = nil
    if x = parse_param(arg)
      ranks = Name.all_ranks.map {|x| x.to_s.downcase}
      if ranks.include?(x)
        result = x.capitalize
      else
        raise error(102, "#{arg} must be one of: (#{ranks.join(', ')})")
      end
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
    if x = parse_param(arg)
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

  # Download a file via HTTP given a URL.  Save it chunk-wise into a temp file,
  # return the name of the file, along with pertinent header information.
  def load_from_url(url)
    tempfile = "#{RAILS_ROOT}/tmp/api_upload.#{$$}"
    header = {}
    uri = URI.parse(url)
    File.open(tempfile, 'w') do |fh|
      Net::HTTP.new(uri.host, uri.port).start do |http|
        http.request_get(uri.request_uri) do |response|
          response.read_body do |chunk|
            fh.write(chunk)
          end
          header['Content-Length'] = response['Content-Length'].to_i
          header['Content-Type']   = response['Content-Type']
          header['Content-MD5']    = response['Content-MD5']
        end
      end
    end
    return [tempfile, header]
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
