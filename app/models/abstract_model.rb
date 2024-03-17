# frozen_string_literal: true

#
#  = Extensions to ApplicationRecord
#
#  == Methods
#
#  type_tag::           Language tag, e.g., :observation, :rss_log, etc.
#
#  == Scopes
#
#  Scopes for collecting objects created (or updated) on, before, after or
#  between a given "%Y-%m-%d" string(s).
#
#  Examples: Observation.created_between("2006-09-01", "2012-09-01")
#            Name.updated_after("2016-12-01")
#
#  created_on::
#  created_after::
#  created_before::
#  created_between::
#  updated_on::
#  updated_after::
#  updated_before::
#  updated_between::
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
#  find_using_wildcards::
#                       Lookup instances with a string that may contain "*"s.
#
#  ==== Report "show" action for object/model
#  show_controller::    These two return the controller and action of the main
#  show_action::          page used to display this object.
#  show_url::           "Official" URL for this database object.
#  show_link_args::     "Official" link_to args for this database object.
#  index_action::       Name of action to display index of these objects
#  index_link_args::    link_to args for this database object's index.
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

  ##############################################################################
  #
  #  :section: Scopes
  #
  ##############################################################################

  scope :created_on, lambda { |ymd_string|
    where(arel_table[:created_at].format("%Y-%m-%d") == ymd_string)
  }
  scope :created_after, lambda { |ymd_string|
    where(arel_table[:created_at].format("%Y-%m-%d") >= ymd_string)
  }
  scope :created_before, lambda { |ymd_string|
    where(arel_table[:created_at].format("%Y-%m-%d") <= ymd_string)
  }
  scope :created_between, lambda { |earliest, latest|
    where(arel_table[:created_at].format("%Y-%m-%d") >= earliest).
      where(arel_table[:created_at].format("%Y-%m-%d") <= latest)
  }
  scope :updated_on, lambda { |ymd_string|
    where(arel_table[:updated_at].format("%Y-%m-%d") == ymd_string)
  }
  scope :updated_after, lambda { |ymd_string|
    where(arel_table[:updated_at].format("%Y-%m-%d") >= ymd_string)
  }
  scope :updated_before, lambda { |ymd_string|
    where(arel_table[:updated_at].format("%Y-%m-%d") <= ymd_string)
  }
  scope :updated_between, lambda { |earliest, latest|
    where(arel_table[:updated_at].format("%Y-%m-%d") >= earliest).
      where(arel_table[:updated_at].format("%Y-%m-%d") <= latest)
  }

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

  # Lookup all instances matching a given wildcard pattern.  If there are no
  # "*" in the pattern, it just does a regular find_by_xxx lookup.  A number
  # of convenience wrappers are included in the major models. Returns nil if
  # none found.
  #
  #   Project.find_using_wildcards("title", "FunDiS *")
  #   Project.find_by_title_with_wildcards("FunDiS *")
  #
  def self.find_using_wildcards(col, str)
    return send(:"find_by_#{col}", str) unless str.include?("*")

    safe_col = connection.quote_column_name(col)
    matches = where("#{safe_col} LIKE ?", str.tr("*", "%"))
    matches.empty? ? nil : matches
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
    self.user_id ||= User.current_id if respond_to?(:user_id=)
    autolog_created if has_rss_log?
  end

  # This is called just after an object is created.
  # 1) It passes off to UserStats, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It finishes attaching the new RssLog if one exists.
  after_create :update_contribution
  def update_contribution
    UserStats.update_contribution(:add, self)
    attach_rss_log_final_step if has_rss_log?
  end

  # This is called just before an object's changes are saved.
  # 1) It passes off to UserStats, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It updates 'updated_at' whenever a record changes.
  # 3) It saves a message to the RssLog.
  #
  # *NOTE*: Use +save_without_our_callbacks+ to save a record without doing
  # either of these things.
  before_update :do_log_update
  def do_log_update
    UserStats.update_contribution(:chg, self)
    autolog_updated if has_rss_log? && !@save_without_our_callbacks
  end

  # This would be called just after an object's changes are saved, but we have
  # no need of such a callback yet.
  # def after_update
  # end

  # This is called just before an object is destroyed.
  # 1) It passes off to UserStats, where it will decide whether this affects a
  #    user's contribution score, and if so update it appropriately.
  # 2) It orphans the old RssLog if it had one.
  # 3) It also saves the id in case we needed to know what the id was later on.
  before_destroy :do_log_destroy
  def do_log_destroy
    UserStats.update_contribution(:del, self)
    autolog_destroyed if has_rss_log? && rss_log.present?
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
  #   def show
  #     @observation = Observation.find(params[:id].to_s)
  #     @observation.update_view_stats
  #     ...
  #   end
  #
  # *NOTE*: this turns off timestamp updating for this class and avoids touching
  # any RssLog, because it uses +save_without_our_callbacks+.
  #
  # *NOTE*: this saves the old stats for the page footer of show_observation,
  # show_name, etc. otherwise the footer will always show the last view as now!
  #
  def update_view_stats
    return unless respond_to?(:num_views=) || respond_to?(:last_view=)

    @old_num_views = num_views
    @old_last_view = last_view
    self.class.record_timestamps = false
    self.num_views = (num_views || 0) + 1 if respond_to?(:num_views=)
    self.last_view = Time.zone.now        if respond_to?(:last_view=)
    save_without_our_callbacks
    self.class.record_timestamps = true
  end

  def old_num_views
    @old_num_views.to_i
  end

  attr_reader :old_last_view

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
    errors.each do |error|
      attribute = error.attribute
      message = error.message
      if /^[A-Z]/.match?(message)
        out << message
      else
        name = attribute.to_s.to_sym.l
        obj = type_tag.to_s.upcase_first.to_sym.l
        out << "#{obj} #{name} #{message}."
      end
    end
    out
  end

  ##############################################################################
  #
  #  :section: Show Controller / Action
  #
  ##############################################################################

  # After all controllers are normalized, consider deleting the
  # normalized/unnormalized conditionals in this method, and delete the
  # sub-methods "controller_normalized?" and "class_defined?".
  # I don't think there will be relevant special cases,
  # i.e., searchable models with singular controller names. JDC 2020-08-02
  #
  # Return the name of the controller (as a string! see below)
  # that handles the "show_<object>" for this object.
  #
  #   Article.show_controller => :articles # for normalized controller
  #
  #   Name.show_controller => :name
  #
  # NOTE: `show_controller` MUST string-interpolate the controller name after
  # a leading forward slash, in order to explicitly specify a "top level"
  # controller. Took me a year to learn again what Joe learned two years ago:
  # Without the forward slash, requests from a nested controller will assume the
  # same nesting. It's very confusing to debug, and almost never what you want.
  #
  # Because of this misleading specificity, I'd like to move away from
  # `show_controller`, and methods composing paths by controller/action args,
  # in favor of Rails explicit path helpers as drawn by routes, but in some
  # cases `show_controller` is practical - some actions handle a polyvalent
  # object whose path cannot be easily interpolated. - AN 10/2022
  #
  def self.show_controller
    "/#{name.pluralize.underscore}" # Rails standard for most controllers
  end

  def show_controller
    self.class.show_controller
  end

  # Has controller been normalized to Rails 6.0 standards:
  #  plural controller name, CRUD action names standardized if they exist
  def self.controller_normalized?
    class_defined?("#{name.pluralize}Controller")
  end

  # stackoverflow.com/questions/45436514/ruby-check-if-controller-defined
  def self.class_defined?(klass)
    Object.const_get(klass)
  rescue StandardError
    false
  end

  # Return the name of the "index_<object>" action (as a symbol)
  # that displays search index for this object.
  #
  #   Article.index_action => :index # normalized controller
  #   Name.index_action => :index # unormalized
  #
  # WARNING.
  # 1. There is no standard Rails action name for displaying a **search** index.
  # 2. Some old MO object classes are not searchable, and thus
  #    lack an action that displays a **search** index.
  # 3. The Rails standard "index" lists **all** objects. And the
  #    corresponding old MO action that lists all objects is "list".
  # 4. Many old MO object classes have > 1 action that produce indices, BUT
  #    some object classes did not have a "list" action
  # So for "normalized" controllers.
  #   Best: each such controller has just one index action.
  #   Otherwise, perhaps define "index_action" in the individual object class.
  # JDC 2021-01-14
  def self.index_action
    :index
  end

  def index_action
    self.class.index_action
  end

  # Return the link_to args of the "index_<object>" action
  # (the index, indexed to a particular id)
  #
  #   Name.index_link_args(12) => {controller: "/names", action: :index,
  #                                id: 12}
  #   name.index_link_args     => {controller: "/names", action: :index,
  #                                id: 12}
  #
  def self.index_link_args(id)
    { controller: show_controller, action: index_action, id: id }
  end

  def index_link_args
    self.class.index_link_args(id)
  end

  # Return the name of the "show_<object>" action (as a symbol)
  # that displays this object.
  #
  #   Article.show_action => :show # normalized controller
  #
  #   Name.show_action => :show_name # unnormalized
  #   name.show_action => :show_name
  #
  def self.show_action
    :show
  end

  def show_action
    self.class.show_action
  end

  # Return the URL of the "show_<object>" action (as a string)
  #
  #   # normalized controller
  #   Article.show_url(12) => "https://mushroomobserver.org/articles/12"
  #
  #   # unnormalized controller
  #   Name.show_url(12) => "https://mushroomobserver.org/names/12"
  #   name.show_url     => "https://mushroomobserver.org/names/12"
  #
  # NOTE: show_controller now has leading forward slash,
  # to account for namespacing
  #
  def self.show_url(id)
    "#{MO.http_domain}#{show_controller}/#{id}"
  end

  def show_url
    self.class.show_url(id)
  end

  # Return the link_to args of the "show_<object>" action
  #
  #   Name.show_link_args(12) => {controller: "/names", action: :show,
  #                               id: 12}
  #   name.show_link_args     => {controller: "/names", action: :show,
  #                               id: 12}
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
    triple = Triple.find_by(subject: show_url, predicate: eol_predicate)
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
  def self.edit_action
    :edit
  end

  def edit_action
    self.class.edit_action
  end

  # Return the URL of the "edit_<object>" action
  #
  #   Name.edit_url(12) => "https://mushroomobserver.org/names/12/edit"
  #   name.edit_url     => "https://mushroomobserver.org/names/12/edit"
  #
  def self.edit_url(id)
    "#{MO.http_domain}/#{edit_controller}/#{id}/#{edit_action}"
  end

  def edit_url
    self.class.edit_url(id)
  end

  # Return the link_to args of the "edit_<object>" action
  #
  #   Name.edit_link_args(12) => {controller: "/names", action: :edit, id: 12}
  #   name.edit_link_args     => {controller: "/names", action: :edit, id: 12}
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

  # Return the name of the "destroy_<object>" action (as a symbol)
  # that displays this object.
  #
  #   Article.destroy_action => :destroy
  #   Name.destroy_action => "destroy_name"
  #
  def self.destroy_action
    :destroy
  end

  def destroy_action
    self.class.destroy_action
  end

  # Return the URL of the "destroy_<object>" action.
  # For CRUD, must pass method: :delete or use destroy_button helper
  #
  #   Name.destroy_url(12) => "https://mushroomobserver.org/names/12"
  #   name.destroy_url     => "https://mushroomobserver.org/names/12"
  #
  def self.destroy_url(id)
    "#{MO.http_domain}/#{destroy_controller}/#{id}"
  end

  def destroy_url
    self.class.destroy_url(id)
  end

  # Return the link_to args of the "destroy_<object>" action
  #
  #   Name.destroy_link_args(12) =>
  #     {controller: "/names", action: :destroy, id: 12}
  #   name.destroy_link_args     =>
  #     {controller: "/names", action: :destroy, id: 12}
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
    touch_when_logging unless new_record? ||
                              args[:touch] == false
    rss_log.add_with_date(tag, args)
  end

  # This allows a model to override touch in this context only, e.g.,
  # Observation caches a log_updated_at value so the activity index doesn't
  # have to do a join to rss_logs
  def touch_when_logging
    touch
  end

  # Add message to RssLog if you're about to destroy this object, creating new
  # RssLog if necessary.
  #
  #   # Log destruction of an Observation (can be destroyed already I think).
  #   orphan_log(:log_observation_destroyed)
  #
  def orphan_log(*)
    rss_log = init_rss_log(orphan: true)
    rss_log.orphan(format_name, *)
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
    autolog_event(:destroyed, orphan: true)
  end

  # Do we log this event? and how?
  def autolog_event(event, orphan: nil)
    return unless RunLevel.is_normal?

    if autolog_events.include?(event)
      touch = false
    elsif autolog_events.include?(:"#{event}!")
      touch = true
    else
      return
    end

    type = type_tag
    msg = :"log_#{type}_#{event}"
    orphan ? orphan_log(msg, touch: touch) : log(msg, touch: touch)
  end

  # Create RssLog and attach it if we don't already have one.  This is
  # primarily for the benefit of old objects that don't have RssLog's already.
  # All new objects automatically get one.
  def init_rss_log(orphan: false)
    return rss_log if rss_log

    rss_log = RssLog.new
    rss_log.created_at = created_at unless new_record?
    rss_log.send(:"#{type_tag}_id=", id) if id && !orphan
    rss_log.save
    attach_rss_log_first_step(rss_log) unless orphan
    rss_log
  end

  # Point object to its new RssLog and save the object unless we are sure
  # it will be saved later.
  def attach_rss_log_first_step(rss_log)
    will_save_later = new_record? || changed?
    self.rss_log_id = rss_log.id
    self.rss_log    = rss_log
    save unless will_save_later
  end

  # Fill in reverse-lookup id in RssLog after creating new record.
  def attach_rss_log_final_step
    return unless rss_log && (rss_log.send(:"#{type_tag}_id") != id)

    rss_log.send(:"#{type_tag}_id=", id)
    rss_log.save
  end

  # Add a note to the notes field with paragraph break between different notes.
  def add_note(note)
    self.notes = notes.present? ? "\n\n#{note}" : note
    save
  end

  def can_edit?(user = User.current)
    !respond_to?(:user) || (user && (self.user_id == user.id))
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
    track_altered_attributes ? (version_if_changed - saved_changes.keys).length < version_if_changed.length : saved_changes? # rubocop:disable Layout/LineLength
  end
end
