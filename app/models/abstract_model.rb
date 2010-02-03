#
#  = Extensions to ActiveRecord::Base
#
#  == Class Methods
#
#  find::               Extend <tt>find(id)</tt> to look up by id _or_ sync_id.
#  safe_find::          Same as <tt>find(id)</tt> except returns nil if not found.
#  find_object::        Look up an object by class name and id.
#  find_by_sql_with_limit::
#                       Add limit to a SQL query, then pass it to find_by_sql.
#  count_by_sql_wrapping_select_query::
#                       Wrap a normal SQL query in a count query, then pass it to count_by_sql.
#  ---
#  show_controller::    These two return the controller and action of the main.
#  show_action::        Page used to display this object.
#
#  == Instance Methods
#
#  before_create::      Callback to fill in defaults for 'created' and 'user'.
#  before_save::        Callback to update 'modified' when record changes.
#  after_create::       Callback to update SiteData and sync_id.
#  before_destroy::     Callback to update SiteData and save id.
#  id_was::             Returns id from before destroy.
#  update_view_stats::  Updates the +num_views+ and +last_view+ fields.
#  update_user_before_save_version::
#                       Callback to update 'user' when versioned record changes.
#  save_without_updating_modified::
#                       Allow certain updates to occur without updating 'modified'.
#  ---
#  dump_errors::        Returns errors in one big printable string.
#  formatted_errors::   Returns errors as an array of printable strings.
#  ---
#  show_controller::    These two return the controller and action of the main.
#  show_action::        Page used to display this object.
#
############################################################################

class AbstractModel < ActiveRecord::Base
  self.abstract_class = true

  # Extend AR.find(id) to accept either local id (integer or all-numeric
  # string) or global sync_id (alphanumeric string).  All else gets delegated
  # to the usual ActiveRecord::Base#find.
  #
  #   name = Name.find(1234)        # local id is 1234
  #   name = Name.find('1234us1')   # gloabl id is '1234us1'
  #
  def self.find(*args)
    if args.length == 1 &&
       (id = args.first) &&
       id.is_a?(String) &&
       id.match(/^\d+[a-z]+\d+$/) &&
       respond_to?(:find_by_sync_id)
      find_by_sync_id(id) or raise ActiveRecord::RecordNotFound,
                                   "Couldn't find #{name} with sync_id=#{id}"
    else
      super
    end
  end

  # Look up record with given ID, returning nil if it no longer exists.
  def self.safe_find(id)
    begin
      self.find(id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  # Look up an object given type and id.
  #
  #   # Look up the object a comment is attached to.
  #   # (Note that in this case this is equivalent to "self.object"!)
  #   obj = Comment.find_object(self.object_type, self.object_id)
  #
  def self.find_object(type, id)
    begin
      type.classify.constantize.find(id.to_i)
    rescue
      nil
    end
  end

  # Add limit to a SQL query, then pass it to find_by_sql.
  #
  #   sql = "SELECT id FROM names WHERE user_id = 123"
  #   names = Name.find_by_sql_with_limit(sql, 20, 10)
  #
  def self.find_by_sql_with_limit(sql, offset, limit)
    sql = sanitize_sql(sql)
    add_limit!(sql, {:limit => limit, :offset => offset})
    find_by_sql(sql)
  end

  # Wrap a normal SQL query in a <tt>COUNT(*)</tt> query, then pass it to
  # count_by_sql.
  #
  #   sql = "SELECT id FROM names WHERE user_id = 123"
  #   num = Name.count_by_sql_wrapping_select_query(sql)
  #
  def self.count_by_sql_wrapping_select_query(sql)
    sql = sanitize_sql(sql)
    count_by_sql("select count(*) from (#{sql}) as my_table")
  end

  # Handy callback that fills in 'created' and 'user' for new records.
  def before_create
    self.created ||= Time.now        if respond_to?('created=')
    self.user_id ||= User.current_id if respond_to?('user_id=')
  end

  # Handy callback that updates 'modified' whenever a record changes.
  def before_save
    if @without_updating_modified
      @without_updating_modified = nil
    else
      self.modified = Time.now if respond_to?('modified=')
    end
  end

  # Allow certain updates to happen without updating 'modified'.
  def save_without_updating_modified
    @without_updating_modified = true
    save
  end

  # Handy callback that updates 'user_id' whenever a versioned record
  # changes non-trivially.
  #
  #   acts_as_versioned
  #   before_save :update_user_if_save_version
  #
  def update_user_if_save_version
    self.user = User.current if save_version?
  end

  # This is called every time an object is created.
  #
  # It passes off to SiteData, where it will decide whether this affects a
  # user's contribution score, and if so update it appropriately.
  #
  # It also assigns sync_ids to new records.  (I can't see how to avoid
  # causing each record to get saved twice.)
  #
  def after_create
    SiteData.update_contribution(:create, self)
    if respond_to?('sync_id=') && !sync_id
      self.sync_id = "#{self.id}#{SERVER_CODE}"
      self.save
    end
  end

  # This is called every time an object is destroyed.
  #
  # It passes off to SiteData, where it will decide whether this affects a
  # user's contribution score, and if so update it appropriately.
  #
  # It also saves the id in case we needed to know what the id was later on.
  #
  def before_destroy
    SiteData.update_contribution(:destroy, self)
    @id_was = self.id
  end

  # Return id from before destroy.
  def id_was; @id_was; end

  # Have any "important" fields been changed?  Used to determine when to
  # update +modified+ and +user+ fields.
  def important_changes?
    !(changed - UNIMPORTANT_FIELDS - extra_unimportant_fields).empty?
  end

  # This is called whenever a user requests the show_object page for an
  # object.  It updates the +num_views+ and +last_view+ fields.
  #
  #   def show_observation
  #     @observation = Observation.find(params[:id])
  #     @observation.update_view_stats
  #   end
  #
  # *NOTE*: these do not cause the +modified+ or +user_id+ fields to be
  # updated, because the before_save callback above ignores these (and
  # several other) fields.
  #
  def update_view_stats
    if respond_to?('num_views=') ||
       respond_to?('last_view=')
      self.num_views = (num_views || 0) + 1 if respond_to?('num_views=')
      self.last_view = Time.now             if respond_to?('last_view=')
      self.save_without_updating_modified
      Transaction.create(
        :method => :view,
        :action => self.class.to_s.underscore,
        :id     => self
      )
    end
  end

  # Dump out error messages for a given instance in a single string.  Useful
  # for debugging:
  #
  #   puts user.dump_errors if TESTING
  #
  def dump_errors
    self.formatted_errors.join("; ")
  end

  # This collects all the error messages for a given instance, and returns
  # them as an array of strings, e.g. for flash_notice().  If an error
  # message is a complete sentence (i.e. starts with uppercase) it does
  # nothing with it; otherwise it prepends the class and attribute like this:
  # "is missing" becomes "Object attribute is missing." Errors are created
  # via validates (magically) or by explicit calls to
  #
  #   obj.errors.add(:attr, "message").
  def formatted_errors
    out = []
    self.errors.each { |attr, msg|
      if msg.match(/^[A-Z]/)
        out << msg
      else
        name = attr.to_s.gsub(/_/, " ")
        obj = self.class.to_s.gsub(/_/, " ")
        out << "#{obj} #{name} #{msg}."
      end
    }
    return out
  end

  # Return the name of the controller (as a simple lowercase string)
  # that handles the "show_<object>" action for this object.
  #
  #   User.show_controller => 'observer'
  #   Name.show_controller => 'name'
  #
  def self.show_controller
    case name
      when 'Observation', 'Naming', 'Vote', 'User'
        return 'observer'
      when 'Name', 'SpeciesList', 'Location', 'Image'
        return name.underscore
      else
        raise(ArgumentError, "Invalid object type, \"#{name.underscore}\".")
    end
  end

  # Return the name of the controller (as a simple lowercase string)
  # that handles the "show_<object>" action for this object.
  #
  #   user.show_controller => 'observer'
  #   name.show_controller => 'name'
  #
  def show_controller
    self.class.show_controller
  end

  # Return the name of the "show_<object>" action (as a simple
  # lowercase string) that displays this object.
  #
  #   User.show_action => 'show_user'
  #   Name.show_action => 'show_name'
  #
  def self.show_action
    'show_' + name.underscore
  end

  # Return the name of the "show_<object>" action (as a simple
  # lowercase string) that displays this object.
  #
  #   user.show_action => 'show_user'
  #   name.show_action => 'show_name'
  #
  def show_action
    self.class.show_action
  end
end
