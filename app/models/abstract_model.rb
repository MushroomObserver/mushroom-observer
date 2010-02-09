#
#  = Extensions to ActiveRecord::Base
#
#  == Class Methods
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
#
#  == Instance Methods
#
#  ==== Callbacks
#  before_create::      Do several things before creating a new record.
#  after_create::       Do several more things after done creating new record.
#  before_save::        Do several things before commiting changes.
#  before_destroy::     Do some cleanup just before destroying an object.
#  id_was::             Returns what the id was from before destroy.
#  update_view_stats::  Updates the +num_views+ and +last_view+ fields.
#  update_user_before_save_version::
#                       Callback to update 'user' when versioned record changes.
#  save_without_updating_modified::
#                       Post some changes _without_ doing the +before_save+ callback above.
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
#  ===== Authors and Editors
#  editors::            User's that have edited this Name.
#  authors::            User's that have made "significant" contributions.
#  add_editor::         Make given user an "editor".
#  add_author::         Make given user an "author".
#  remove_author::      Demote given user to "editor".
#  author_join_table::  Table used to list authors.
#  editor_join_table::  Table used to list editors.
#  past_version_table:: Table used to keep past versions.
#  check_add_author::   Add User as author/editor after making change.
#  author_worthy?::     Is this object sufficiently well-defined to warrant authors?
#  subtract_author_contributions::
#                       Subtract authorship/editorship contributions after destroy.
#
############################################################################

class AbstractModel < ActiveRecord::Base
  self.abstract_class = true

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
    self.created ||= Time.now        if respond_to?('created=')
    self.user_id ||= User.current_id if respond_to?('user_id=')
    if has_rss_log?
      autolog_created
    end
  end

  # This is called just after an object is created.
  # 1) It passes off to SiteData, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It also assigns sync_ids to new records.  (I can't see how to avoid
  #    causing each record to get saved twice.)
  # 3) Lastly, it finishes attaching the new RssLog if one exists.
  def after_create
    SiteData.update_contribution(:create, self)
    if respond_to?('sync_id=') && !sync_id
      self.sync_id = "#{self.id}#{SERVER_CODE}"
      self.save_without_updating_modified
    end
    if has_rss_log?
      attach_rss_log
    end
  end

  # This is called just before an object is saved.
  # 1) It updates 'modified' whenever a record changes.
  # 2) It saves a message to the RssLog.
  # 3) It adds the current User as author or editor.
  #
  # *NOTE*: Use +save_without_updating_modified+ to save a record without doing
  # either of these things.
  def before_save
    if @without_updating_modified
      @without_updating_modified = nil
    else
      self.modified = Time.now if respond_to?('modified=')
      if has_rss_log? and !new_record?
        autolog_updated
      end
      if has_authors?
        check_add_author
      end
    end
  end

  # Bypass the part of the +before_save+ callback that causes 'modified' to be
  # updated each time a record is saved.
  def save_without_updating_modified
    @without_updating_modified = true
    save
  end

  # This is called just before an object is destroyed.
  # 1) It passes off to SiteData, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It orphans the old RssLog if it had one.
  # 3) It also saves the id in case we needed to know what the id was later on.
  def before_destroy
    SiteData.update_contribution(:destroy, self)
    @id_was = self.id
    if has_rss_log?
      autolog_destroyed
    end
    if has_authors?
      subtract_author_contributions
    end
  end

  # Return id from before destroy.
  def id_was; @id_was; end

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
  # +save_without_updating_modified+.
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
      when 'Comment', 'Image', 'Location', 'Name', 'SpeciesList'
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
    if autolog_events.include?(event)
      touch = false
    elsif autolog_events.include?("#{event}!".to_sym)
      touch = true
    else
      touch = nil
    end
    if touch != nil
      msg = "log_object_#{event}".to_sym
      type = self.class.name.underscore.to_sym.l
      if orphan
        orphan_log(msg, :type => type, :touch => touch)
      else
        log(msg, :type => type, :touch => touch)
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
        rss_log.send("#{self.class.name.underscore}_id=", id) if id
        self.rss_log = rss_log
        # Save it now unless we are sure it will be saved later.
        self.save if !new_record? && !changed?
      end
      # Always save the rss_log.
      rss_log.save
      result = rss_log
    end
    # We need to return it in case we created an orphaned log, otherwise
    # the caller won't have access to it!
    return result
  end

  # Fill in reverse-lookup id in RssLog after creating new record.
  def attach_rss_log
    if rss_log and
       rss_log.send("#{self.class.name.underscore}_id") != id
      rss_log.send("#{self.class.name.underscore}_id=", id)
      rss_log.save
    end
  end

  ##############################################################################
  #
  #  :section: Authors and Editors
  #
  ##############################################################################

  # Does this model keep track of authors/editors?
  def self.has_authors?
    !!reflect_on_association(:authors)
  end

  # Does this model keep track of authors/editors?
  def has_authors?
    !!self.class.reflect_on_association(:authors)
  end

  # Name of the join table used to list authors.
  def author_join_table
    "authors_#{self.class.table_name}".to_sym
  end

  # Name of the join table used to list editors.
  def editor_join_table
    "editors_#{self.class.table_name}".to_sym
  end

  # Name of the join table used to hold past versions.
  def past_version_table
    "past_#{self.class.table_name}".to_sym
  end

  # When destroying an object, subtract contributions due to
  # authorship/editorship.
  def subtract_author_contributions
    for user in authors
      SiteData.update_contribution(:remove, self, author_join_table, user)
    end
    for user in editors
      SiteData.update_contribution(:remove, self, editor_join_table, user)
    end
  end

  # Add a User on as an "author".  Saves User if changed.  Returns nothing.
  def add_author(user)
    if not authors.member?(user)
      authors.push(user)
      SiteData.update_contribution(:add, self, author_join_table, user)
      if editors.member?(user)
        editors.delete(user)
        SiteData.update_contribution(:remove, self, editor_join_table, user)
      end
    end
  end

  # Demote a User to "editor".  Saves User if changed.  Returns nothing.
  def remove_author(user)
    if authors.member?(user)
      authors.delete(user)
      SiteData.update_contribution(:remove, self, author_join_table, user)
      if not editors.member?(user) and
        # Make sure user has actually made at least one change.
        self.class.connection.select_value %(
          SELECT id FROM #{past_version_table}
          WHERE #{self.class.name.underscore}_id = #{id} AND user_id = #{user.id}
          LIMIT 1
        )
        editors.push(user)
        SiteData.update_contribution(:add, self, editor_join_table, user)
      end
    end
  end

  # Add a user on as an "editor".
  def add_editor(user)
    if not authors.member?(user) and not editors.member?(user)
      editors.push(user)
      SiteData.update_contribution(:add, self, editor_join_table, user)
    end
  end

  # Callback that updates editors and/or authors after a User makes a change.
  # If the Name has no author and they've made sufficient contributions, they
  # get promoted to author by default.  In all cases make sure the user is
  # added on as an editor.
  def check_add_author
    if user = User.current
      if authors.empty? && author_worthy?
        add_author(user)
      else
        add_editor(user)
      end
    end
  end

  # By default make the creating User the first author.  That is, assume it's
  # worthwhile having authors on all objects, no matter how poorly defined.
  def author_worthy?; true; end
end
