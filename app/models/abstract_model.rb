# frozen_string_literal: true
#
#  = Extensions to ApplicationRecord
#
#  == Methods
#
#  type_tag::           Language tag, e.g., :observation, :rss_log, etc.
#  enum_default_value   Default value (as a Symbol) of an enum attribute
#                       Ex: User.enum_default_value(:image_size) => :medium
#
#  ==== Extensions to "find"
#  safe_find::          Same as <tt>find(id)</tt> but return nil if not found.
#  find_object::        Look up an object by class name and id.
#  find_by_sql_with_limit::
#                       Add limit to a SQL query, then pass it to find_by_sql.
#  count_by_sql_wrapping_select_query::
#                       Wrap a normal SQL query in a count query,
#                       then pass it to count_by_sql.
#  revert_clone::       Clone and revert to old version
#                       (or return nil if version not found).
#
#  ==== Report "show" action for object/model
#  show_controller::    These two return the controller and action of the main.
#  show_action::        Page used to display this object.
#  show_url::           "Official" URL for this database object.
#  show_link_args::     "Official" link_to args for this database object.
#  index_action::       Page used to display index of these objects.
#
#  ==== Callbacks
#  before_create::      Do several things before creating a new record.
#  after_create::       Do several more things after done creating new record.
#  before_update::      Do several things before commiting changes.
#  before_destroy::     Do some cleanup just before destroying an object.
#  id_was::             Returns what the id was from before destroy.
#  update_view_stats::  Updates the +num_views+ and +last_view+ fields.
#  update_user_before_save_version::
#                       Callback to update 'user' when versioned record changes.
#  save_without_our_callbacks::
#                       Post changes _without_ doing
#                       the +before_update+ callback above.
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
#  log_create_image::   Log addition of new Image.
#  log_reuse_image::    Log reuse of old Image.
#  log_update_image::   Log update to Image.
#  log_remove_image::   Log removal of Image.
#  log_destroy_image::  Log destruction of Image.
#  init_rss_log::       Create and attach RssLog if not already there.
#  attach_rss_log::     Attach RssLog after creating new record.
#  autolog_created::    Callback to log creation.
#  autolog_updated::    Callback to log an update.
#  autolog_destroyed::  Callback to log destruction.
#
############################################################################

class AbstractModel < ApplicationRecord
  self.abstract_class = true

  def self.acts_like_model?
    true
  end

  def acts_like_model?
    true
  end

  # Language tag for name, e.g. :observation, :rss_log, etc.
  def self.type_tag
    name.underscore.to_sym
  end

  # Language tag for name, e.g. :observation, :rss_log, etc.
  def type_tag
    self.class.name.underscore.to_sym
  end

  # Default value (as a symbol) for an enum attribute
  def self.enum_default_value(attr)
    send(attr.to_s.pluralize).hash.key(default_cardinal(attr)).to_sym
  end

  # number (or nil) that is the default value for attr
  def self.default_cardinal(attr)
    column_defaults[attr.to_s]
  end

  ##############################################################################
  #
  #  :section: "Find" Extensions
  #
  ##############################################################################

  # Make full clone of the present instance, then revert it to an older version.
  # Returns +nil+ if +version+ not found.
  def revert_clone(version)
    return self if self.version == version

    result = self.class.find(id)
    result = nil unless result.revert_to(version)
    result
  end

  # Look up record with given ID, returning nil if it no longer exists.
  def self.safe_find(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # Look up an object given type and id.
  #
  #   # Look up the object a comment is attached to.
  #   # (Note that in this case this is equivalent to "self.object"!)
  #   obj = Comment.find_object(self.object_type, self.object_id)
  #
  def self.find_object(type, id)
    type.classify.constantize.find(id.to_i)
  rescue NameError, ActiveRecord::RecordNotFound
    nil
  end

  # Add limit to a SQL query, then pass it to find_by_sql.
  #
  #   sql = "SELECT id FROM names WHERE user_id = 123"
  #   names = Name.find_by_sql_with_limit(sql, 20, 10)
  #
  def self.find_by_sql_with_limit(sql, offset, limit)
    sql = sanitize_sql(sql)
    add_limit!(sql, limit: limit, offset: offset)
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
  # 1) It fills in 'created_at' and 'user' for new records.
  # 2) And it creates a new RssLog if this model accepts one, and logs its
  #    creation.
  before_create :set_user_and_autolog
  def set_user_and_autolog
    # self.created_at ||= Time.now        if respond_to?('created_at=')
    # self.updated_at ||= Time.now        if respond_to?('updated_at=')
    self.user_id ||= User.current_id if respond_to?("user_id=")
    autolog_created if has_rss_log?
  end

  # This is called just after an object is created.
  # 1) It passes off to SiteData, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It finishes attaching the new RssLog if one exists.
  after_create :update_contribution
  def update_contribution
    SiteData.update_contribution(:add, self)
    attach_rss_log if has_rss_log?
  end

  # This is called just before an object's changes are saved.
  # 1) It passes off to SiteData, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It updates 'updated_at' whenever a record changes.
  # 3) It saves a message to the RssLog.
  #
  # *NOTE*: Use +save_without_our_callbacks+ to save a record without doing
  # either of these things.
  before_update :do_log_update
  def do_log_update
    # raise "do_log_update"
    SiteData.update_contribution(:chg, self)
    autolog_updated if has_rss_log? && !@save_without_our_callbacks
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
  before_destroy :do_log_destroy
  def do_log_destroy
    SiteData.update_contribution(:del, self)
    autolog_destroyed if has_rss_log?
    @id_was = id
  end

  # This would be called just after an object is destroyed, but we have no need
  # of such a callback yet.
  # def after_destroy
  # end

  # Bypass the part of the +before_save+ callback that causes 'updated_at' to be
  # updated each time a record is saved.
  def save_without_our_callbacks
    @save_without_our_callbacks = true
    save
  end

  # Clears the +@save_without_our_callbacks+ flag after save.
  after_save :clear_callback_flag
  def clear_callback_flag
    @save_without_our_callbacks = nil
  end

  # Return id from before destroy.
  attr_reader :id_was

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
  #     @observation = Observation.find(params[:id].to_s)
  #     @observation.update_view_stats
  #     ...
  #   end
  #
  # *NOTE*: this turns off timestamp updating for this class and avoids touching
  # any RssLog, because it uses +save_without_our_callbacks+.
  #
  def update_view_stats
    return unless respond_to?("num_views=") || respond_to?("last_view=")

    self.class.record_timestamps = false
    self.num_views = (num_views || 0) + 1 if respond_to?("num_views=")
    self.last_view = Time.zone.now        if respond_to?("last_view=")
    save_without_our_callbacks
    self.class.record_timestamps = true
  end

  ##############################################################################
  #
  #  :section: Error Handling
  #
  ##############################################################################

  # Dump out error messages for a given instance in a single string.  Useful
  # for debugging:
  #
  #   puts user.dump_errors if Rails.env == "test"
  #
  def dump_errors
    formatted_errors.join("; ")
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
    errors.each do |attr, msg|
      if /^[A-Z]/.match?(msg)
        out << msg
      else
        name = attr.to_s.to_sym.l
        obj = type_tag.to_s.upcase_first.to_sym.l
        out << "#{obj} #{name} #{msg}."
      end
    end
    out
  end

  ##############################################################################
  #
  #  :section: Show Controller / Action
  #
  ##############################################################################

  # Return the name of the controller (as a simple lowercase string)
  # that handles the "show_<object>" action for this object.
  #
  #   Name.show_controller => "name"
  #   name.show_controller => "name"
  #
  def self.show_controller
    name.underscore
  end

  def show_controller
    self.class.show_controller
  end

  # Return the name of the "index_<object>" action (as a simple
  # lowercase string) that displays search index for this object.
  #
  #   Name.index_action => "index_name"
  #   name.index_action => "index_name"
  #
  def self.index_action
    "index_" + name.underscore
  end

  def index_action
    self.class.index_action
  end

  # Return the name of the "show_<object>" action (as a simple
  # lowercase string) that displays this object.
  #
  #   Name.show_action => "show_name"
  #   name.show_action => "show_name"
  #
  def self.show_action
    "show_" + name.underscore
  end

  def show_action
    self.class.show_action
  end

  # Return the URL of the "show_<object>" action
  #
  #   Name.show_url(12) => "http://mushroomobserver.org/names/show_name/12"
  #   name.show_url     => "http://mushroomobserver.org/names/show_name/12"
  #
  def self.show_url(id)
    "#{MO.http_domain}/#{show_controller}/#{show_action}/#{id}"
  end

  def show_url
    self.class.show_url(id)
  end

  # Return the link_to args of the "show_<object>" action
  #
  #   Name.show_link_args(12) => {controller: :names, action: :show_name, id: 12}
  #   name.show_link_args     => {controller: :names, action: :show_name, id: 12}
  #
  def self.show_link_args(id)
    { controller: show_controller, action: show_action, id: id }
  end

  def show_link_args
    self.class.show_link_args(id)
  end

  # Return the URL for the EOL resource corresponding to this object.
  #
  #   name.eol_url => "http://eol.org/blah/blah/blah"
  #
  def eol_url
    triple = Triple.find_by_subject_and_predicate(show_url, eol_predicate)
    triple&.object
  end

  def self.eol_predicate
    ":eol#{name}"
  end

  def eol_predicate
    self.class.eol_predicate
  end

  ##############################################################################
  #
  #  :section: Edit Controller / Action
  #
  ##############################################################################

  def self.edit_controller
    show_controller
  end

  def edit_controller
    show_controller
  end

  # Return the name of the "edit_<object>" action (as a simple
  # lowercase string) that displays this object.
  #
  #   Name.edit_action => "edit_name"
  #   name.edit_action => "edit_name"
  #
  def self.edit_action
    "edit_" + name.underscore
  end

  def edit_action
    self.class.edit_action
  end

  # Return the URL of the "edit_<object>" action
  #
  #   Name.edit_url(12) => "http://mushroomobserver.org/names/edit_name/12"
  #   name.edit_url     => "http://mushroomobserver.org/names/edit_name/12"
  #
  def self.edit_url(id)
    "#{MO.http_domain}/#{edit_controller}/#{edit_action}/#{id}"
  end

  def edit_url
    self.class.edit_url(id)
  end

  # Return the link_to args of the "edit_<object>" action
  #
  #   Name.edit_link_args(12) => {controller: :names, action: :edit_name, id: 12}
  #   name.edit_link_args     => {controller: :names, action: :edit_name, id: 12}
  #
  def self.edit_link_args(id)
    { controller: edit_controller, action: edit_action, id: id }
  end

  def edit_link_args
    self.class.edit_link_args(id)
  end

  ##############################################################################
  #
  #  :section: Destroy Controller / Action
  #
  ##############################################################################

  def self.destroy_controller
    show_controller
  end

  def destroy_controller
    show_controller
  end

  # Return the name of the "destroy_<object>" action (as a simple
  # lowercase string) that displays this object.
  #
  #   Name.destroy_action => "destroy_name"
  #   name.destroy_action => "destroy_name"
  #
  def self.destroy_action
    "destroy_" + name.underscore
  end

  def destroy_action
    self.class.destroy_action
  end

  # Return the URL of the "destroy_<object>" action
  #
  #   Name.destroy_url(12) => "http://mushroomobserver.org/names/destroy_name/12"
  #   name.destroy_url     => "http://mushroomobserver.org/names/destroy_name/12"
  #
  def self.destroy_url(id)
    "#{MO.http_domain}/#{destroy_controller}/#{destroy_action}/#{id}"
  end

  def destroy_url
    self.class.destroy_url(id)
  end

  # Return the link_to args of the "destroy_<object>" action
  #
  #   Name.destroy_link_args(12) =>
  #     {controller: :names, action: :destroy_name, id: 12}
  #   name.destroy_link_args     =>
  #     {controller: :names, action: :destroy_name, id: 12}
  #
  def self.destroy_link_args(id)
    { controller: destroy_controller, action: destroy_action, id: id }
  end

  def destroy_link_args
    self.class.destroy_link_args(id)
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
  class_attribute :autolog_events
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
  def log(tag, args = {})
    init_rss_log unless rss_log
    touch unless new_record? || # rubocop:disable Rails/SkipsModelValidations
                 args[:touch] == false
    rss_log.add_with_date(tag, args)
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

  # Logs addition of new Image.
  def log_create_image(image)
    log_image(:log_image_created, image, true)
  end

  # Logs addition of existing Image.
  def log_reuse_image(image)
    log_image(:log_image_reused, image, true)
  end

  # Logs update of Image.
  def log_update_image(image)
    log_image(:log_image_updated, image, false)
  end

  # Logs removal of Image.
  def log_remove_image(image)
    log_image(:log_image_removed, image, false)
  end

  # Logs destruction of Image.
  def log_destroy_image(image)
    log_image(:log_image_destroyed, image, false)
  end

  # Log addition of new Sequence to object
  def log_add_sequence(sequence)
    log_sequence(:log_sequence_added, sequence, true)
  end

  # Log Sequence's accession to archive
  def log_accession_sequence(sequence)
    log_sequence(:log_sequence_accessioned, sequence, true)
  end

  def log_update_sequence(sequence)
    log_sequence(:log_sequence_updated, sequence, false)
  end

  def log_destroy_sequence(sequence)
    log_sequence(:log_sequence_destroyed, sequence, true)
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
  def autolog_event(event, orphan = nil)
    return unless RunLevel.is_normal?

    touch = if autolog_events.include?(event)
              false
            elsif autolog_events.include?("#{event}!".to_sym)
              true
            end
    return if touch.nil?

    type = type_tag
    msg = "log_#{type}_#{event}".to_sym
    orphan ? orphan_log(msg, touch: touch) : log(msg, touch: touch)
  end

  # Create RssLog and attach it if we don't already have one.  This is
  # primarily for the benefit of old objects that don't have RssLog's already.
  # All new objects automatically get one.
  def init_rss_log(orphan = false)
    result = nil
    if rss_log
      result = rss_log
    else
      rss_log = RssLog.new
      # Don't attach to object if about to destroy.
      if !orphan
        rss_log.send("#{type_tag}_id=", id) if id
        rss_log.save
        # Save it now unless we are sure it will be saved later.
        need_to_save = !new_record? && !changed?
        self.rss_log_id = rss_log.id
        self.rss_log    = rss_log
        save if need_to_save
      else
        # Always save the rss_log.
        rss_log.save
      end
      result = rss_log
    end
    # We need to return it in case we created an orphaned log, otherwise
    # the caller won't have access to it!
    result
  end

  # Fill in reverse-lookup id in RssLog after creating new record.
  def attach_rss_log
    return unless rss_log && (rss_log.send("#{type_tag}_id") != id)

    rss_log.send("#{type_tag}_id=", id)
    rss_log.save
  end

  # The label which is displayed for the model's tab in the RssLog tabset
  # e.g. "Names", "Species Lists"
  def self.rss_log_tab_label
    to_s.pluralized_title
  end

  # Add a note
  def add_note(note)
    if notes
      self.notes += "\n\n" + note
    else
      self.notes = note
    end
    save
  end

  def process_image_reuse(image, query_params)
    add_image(image)
    log_reuse_image(image)
    {
      controller: show_controller,
      action: show_action,
      id: id,
      q: query_params[:q]
    }
  end

  def can_edit?(user = User.current)
    !respond_to?("user") || (user && (self.user == user))
  end

  def string_with_id(str)
    id_str = id || "?"
    str + " (#{id_str})"
  end

  ##############################################################################
  #
  #  :section: versions
  #
  ##############################################################################

  # Replacement for "altered?"" method of cures_acts_as_versioned gem
  # The gem method is incompatible with Rails 2.2, and the gem is not maintained
  # TODO: replace the gem.
  # See notes at https://www.pivotaltracker.com/story/show/163189614
  def saved_version_changes?
    track_altered_attributes ? (version_if_changed - saved_changes.keys).length < version_if_changed.length : saved_changes? # rubocop:disable Metrics/LineLength
  end

  ##############################################################################

  private

  def log_image(tag, image, touch) # :nodoc:
    name = "#{:Image.t} ##{image.id || image.was || "??"}"
    log(tag, name: name, touch: touch)
  end

  def log_sequence(tag, sequence, touch) # :nodoc:
    name = "#{:SEQUENCE.t} ##{sequence.id || "??"}"
    log(tag, name: name, touch: touch)
  end
end
