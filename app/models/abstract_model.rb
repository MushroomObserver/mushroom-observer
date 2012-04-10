# encoding: utf-8
#
#  = Extensions to ActiveRecord::Base
#
#  == Methods
#
#  type_tag::           Language tag, e.g., :observation, :rss_log, etc.
#
#  ==== Extensions to "find"
#  find::               Extend <tt>find(id)</tt> to look up by id _or_ sync_id.
#  safe_find::          Same as <tt>find(id)</tt> except returns nil if not found.
#  find_object::        Look up an object by class name and id.
#  find_by_sql_with_limit::
#                       Add limit to a SQL query, then pass it to find_by_sql.
#  count_by_sql_wrapping_select_query::
#                       Wrap a normal SQL query in a count query, then pass it to count_by_sql.
#
#  ==== Report "show" action for object/model
#  show_controller::    These two return the controller and action of the main.
#  show_action::        Page used to display this object.
#  index_action::       Page used to display index of these objects.
#
#  ==== Callbacks
#  before_create::      Do several things before creating a new record.
#  after_create::       Do several more things after done creating new record.
#  before_update::      Do several things before commiting changes.
#  before_destroy::     Do some cleanup just before destroying an object.
#  id_was::             Returns what the id was from before destroy.
#  set_sync_id::        Fills in +sync_id+ after id is established.
#  update_view_stats::  Updates the +num_views+ and +last_view+ fields.
#  update_user_before_save_version::
#                       Callback to update 'user' when versioned record changes.
#  save_without_our_callbacks::
#                       Post changes _without_ doing the +before_update+ callback above.
#
#  ==== Error handling
#  dump_errors::        Returns errors in one big printable string.
#  formatted_errors::   Returns errors as an array of printable strings.
#
#  ==== RSS log
#  autolog_events::     Configure which events are automatically logged.
#  has_rss_log?::       Can this model take an RssLog?
#  log::                Add line to RssLog.
#  orphan_log::         Add line to RssLog before destroying object.
#  init_rss_log::       Create and attach RssLog if not already there.
#  attach_rss_log::     Attach RssLog after creating new record.
#  autolog_created::    Callback to log creation.
#  autolog_updated::    Callback to log an update.
#  autolog_destroyed::  Callback to log destruction.
#
############################################################################

class AbstractModel < ActiveRecord::Base
  self.abstract_class = true

  def self.acts_like_model?; true; end
  def acts_like_model?; true; end

  # Language tag for name, e.g. :observation, :rss_log, etc.
  def self.type_tag
    self.name.underscore.to_sym
  end

  # Language tag for name, e.g. :observation, :rss_log, etc.
  def type_tag
    self.class.name.underscore.to_sym
  end

  ##############################################################################
  #
  #  :section: "Find" Extensions
  #
  ##############################################################################

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
  def self.safe_find(id, *args)
    begin
      self.find(id, *args)
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
    type.classify.constantize.find(id.to_i)
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

  # Return the version number given an array-like index.  Use negative indexes
  # to specify index from the end.  Return Fixnum, or nil if doesn't exist.
  #
  #   name.find_version(-1)  # Last (current) version.
  #   name.find_version(-2)  # Next-to-last (previous) version.
  #   name.find_version(0)   # First (oldest) version. (Should always be 1?)
  #
  # *NOTE*: Roughly equivalent to but far more efficient than the following:
  #
  #   name.versions[idx].version
  #
  def find_version(idx)
    if idx < 0
      limit = "DESC LIMIT 1, #{-idx-1}"
    else
      limit = "ASC LIMIT 1, #{idx}"
    end
    num = self.class.connection.select_value %(
      SELECT version FROM #{versioned_table_name}
      WHERE #{self.type_tag}_id = #{id}
      ORDER BY version #{limit}
    )
    num ? num.to_i : nil
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # This is called just before an object is created.
  # 1) It fills in 'created' and 'user' for new records.
  # 2) And it creates a new RssLog if this model accepts one, and logs its
  #    creation.
  def before_create
    self.created  ||= Time.now        if respond_to?('created=')
    self.modified ||= Time.now        if respond_to?('modified=')
    self.user_id  ||= User.current_id if respond_to?('user_id=')
    autolog_created                   if has_rss_log?
  end

  # This is called just after an object is created.
  # 1) It passes off to SiteData, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It also assigns sync_ids to new records.  (I can't see how to avoid
  #    causing each record to get saved twice.)
  # 3) Lastly, it finishes attaching the new RssLog if one exists.
  def after_create
    SiteData.update_contribution(:add, self)
    set_sync_id    if respond_to?('sync_id=') && !sync_id
    attach_rss_log if has_rss_log?
  end

  # This is called just before an object's changes are saved.
  # 1) It updates 'modified' whenever a record changes.
  # 2) It saves a message to the RssLog.
  #
  # *NOTE*: Use +save_without_our_callbacks+ to save a record without doing
  # either of these things.
  def before_update
    if !@save_without_our_callbacks
      self.modified = Time.now if respond_to?('modified=') && !self.modified_changed?
      autolog_updated          if has_rss_log?
    end
  end

  # This would be called just after an object's changes are saved, but we have
  # no need of such a callback yet.
  # def after_update
  # end

  # This is called just before an object is destroyed.
  # 1) It passes off to SiteData, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It orphans the old RssLog if it had one.
  # 3) It also saves the id in case we needed to know what the id was later on.
  def before_destroy
    SiteData.update_contribution(:del, self)
    autolog_destroyed if has_rss_log?
    @id_was = self.id
  end

  # This would be called just after an object is destroyed, but we have no need
  # of such a callback yet.
  # def after_destroy
  # end

  # Bypass the part of the +before_save+ callback that causes 'modified' to be
  # updated each time a record is saved.
  def save_without_our_callbacks
    @save_without_our_callbacks = true
    save
  end

  # Clears the +@save_without_our_callbacks+ flag after save.
  def after_save
    @save_without_our_callbacks = nil
  end

  # Return id from before destroy.
  def id_was; @id_was; end

  # Set the sync id after an id is established.  Use low-level call to void
  # any possible confusion and/or overhead dealing with callbacks.  It would
  # be super-cool if mysql gave us a way to make this the default value...
  def set_sync_id
    self.sync_id = sync_id = "#{id}#{SERVER_CODE}"
    self.class.connection.update %(
      UPDATE #{self.class.table_name} SET sync_id = '#{sync_id}'
      WHERE id = #{id}
    )
  end

  # Handy callback a model may choose to use that updates 'user_id' whenever a
  # versioned record changes non-trivially.
  #
  #   acts_as_versioned ...
  #   before_save :update_user_if_save_version
  #
  def update_user_if_save_version
    self.user = User.current if save_version?
  end

  # Call this whenever a User requests the show_object page for an
  # object.  It updates the +num_views+ and +last_view+ fields.
  #
  #   def show_observation
  #     @observation = Observation.find(params[:id])
  #     @observation.update_view_stats
  #     ...
  #   end
  #
  # *NOTE*: this does not cause 'modified' to be updated, because it uses
  # +save_without_our_callbacks+.
  #
  def update_view_stats
    if respond_to?('num_views=') ||
       respond_to?('last_view=')
      self.num_views = (num_views || 0) + 1 if respond_to?('num_views=')
      self.last_view = Time.now             if respond_to?('last_view=')
      self.save_without_our_callbacks
    end
  end

  ##############################################################################
  #
  #  :section: Error Handling
  #
  ##############################################################################

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
    self.errors.each do |attr, msg|
      if msg.match(/^[A-Z]/)
        out << msg
      else
        name = attr.to_s.to_sym.l
        obj = self.type_tag.to_s.capitalize_first.to_sym.l
        out << "#{obj} #{name} #{msg}."
      end
    end
    return out
  end

  ##############################################################################
  #
  #  :section: Show Controller / Action
  #
  ##############################################################################

  # Return the name of the controller (as a simple lowercase string)
  # that handles the "show_<object>" action for this object.
  #
  #   User.show_controller => 'observer'
  #   Name.show_controller => 'name'
  #
  def self.show_controller
    case name
      when 'Observation', 'Naming', 'Vote', 'User', 'RssLog'
        return 'observer'
      when 'Comment', 'Image', 'Location', 'Name', 'Project', 'SpeciesList'
        return name.underscore
      when /Description$/
        return $`.underscore
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

  # Return the name of the "index_<object>" action (as a simple
  # lowercase string) that displays search index for this object.
  #
  #   User.index_action => 'index_user'
  #   Name.index_action => 'index_name'
  #
  def self.index_action
    'index_' + name.underscore
  end

  # Return the name of the "index_<object>" action (as a simple
  # lowercase string) that displays this object.
  #
  #   user.index_action => 'index_user'
  #   name.index_action => 'index_name'
  #
  def index_action
    self.class.index_action
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

  ##############################################################################
  #
  #  :section: RSS Log
  #
  ##############################################################################

  # By default do NOT automatically log creation/update/destruction.  Override
  # this with an array of zero or more of the following:
  # * :created -- automatically log creation
  # * :created! -- automatically log creation and raise to top of RSS feed
  # * :updated -- automatically log updates
  # * :updated! -- automatically log updates and raise to top of RSS feed
  # * :destroyed -- automatically log destruction
  # * :destroyed! -- automatically log destruction and raise to top of RSS feed
  superclass_delegating_accessor :autolog_events
  self.autolog_events = []

  # Is this model capable of attaching an RssLog?
  def self.has_rss_log?
    !!reflect_on_association(:rss_log)
  end

  # Is this model capable of attaching an RssLog?
  def has_rss_log?
    !!self.class.reflect_on_association(:rss_log)
  end

  # Add message to RssLog, creating one if necessary.
  #
  #    # Log that it was changed by @user, and "touch" the log so it appears
  #    # at the top of the RSS feed.
  #    obj.log(:log_observation_updated)
  #
  def log(*args)
    init_rss_log if !rss_log
    rss_log.add_with_date(*args)
  end

  # Add message to RssLog if you're about to destroy this object, creating new
  # RssLog if necessary.
  #
  #   # Log destruction of an Observation (can be destroyed already I think).
  #   orphan_log(:log_observation_destroyed)
  #
  def orphan_log(*args)
    rss_log = init_rss_log(:orphan)
    rss_log.orphan(format_name, *args)
  end

  # Callback that logs creation.
  def autolog_created
    autolog_event(:created)
  end

  # Callback that logs update.
  def autolog_updated
    autolog_event(:updated)
  end

  # Callback that logs destruction.
  def autolog_destroyed
    autolog_event(:destroyed, :orphan)
  end

  # Do we log this event? and how?
  def autolog_event(event, orphan=nil)
    if RunLevel.is_normal?
      if autolog_events.include?(event)
        touch = false
      elsif autolog_events.include?("#{event}!".to_sym)
        touch = true
      else
        touch = nil
      end
      if touch != nil
        type = self.type_tag
        msg = "log_#{type}_#{event}".to_sym
        if orphan
          orphan_log(msg, :touch => touch)
        else
          log(msg, :touch => touch)
        end
      end
    end
  end

  # Create RssLog and attach it if we don't already have one.  This is
  # primarily for the benefit of old objects that don't have RssLog's already.
  # All new objects automatically get one.
  def init_rss_log(orphan=false)
    result = nil
    if self.rss_log
      result = self.rss_log
    else
      rss_log = RssLog.new
      # Don't attach to object if about to destroy.
      if !orphan
        rss_log.send("#{self.type_tag}_id=", id) if id
        rss_log.save
        # Save it now unless we are sure it will be saved later.
        need_to_save = !new_record? && !changed?
        self.rss_log_id = rss_log.id
        self.rss_log    = rss_log
        self.save if need_to_save
      else
        # Always save the rss_log.
        rss_log.save
      end
      result = rss_log
    end
    # We need to return it in case we created an orphaned log, otherwise
    # the caller won't have access to it!
    return result
  end

  # Fill in reverse-lookup id in RssLog after creating new record.
  def attach_rss_log
    if rss_log and
       rss_log.send("#{self.type_tag}_id") != id
      rss_log.send("#{self.type_tag}_id=", id)
      rss_log.save
    end
  end
  
  # Add a note
  def add_note(note)
    if self.notes
      self.notes += "\n\n" + note
    else
      self.notes = note
    end
    save
  end
end
