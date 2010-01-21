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
#  unimportant_fields:: Tell us which fields to ignore when deciding when to update +modified+ and +user+.
#
#  == Instance Methods
#
#  before_save::        Callback to update 'modified' when record changes.
#  after_create::       Callback to update SiteData and sync_id.
#  before_destroy::     Callback to update SiteData and save id.
#  id_was::             Returns id from before destroy.
#  important_changes?:: Like +changed?+ but it only checks "important" fields.
#  ---
#  dump_errors::        Returns errors in one big printable string.
#  formatted_errors::   Returns errors as an array of printable strings.
#  ---
#  show_controller::    These two return the controller and action of the main.
#  show_action::        Page used to display this object.
#
############################################################################

module ActiveRecord
  class MO < ActiveRecord::Base

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

    # Handy callback that updates 'modified' and 'user_id' whenever the record
    # changes.  (It also fills in 'created' the first time through, just in
    # case we forgot to do so in the controller.)
    def before_save
      if new_record? || important_changes?
        now = Time.now
        if respond_to?('created=')
          self.created ||= now
        end
        if respond_to?('modified=') && !modified_changed?
          self.modified = now
        end
        if User.current && respond_to?('user=') && !user_id_changed?
          self.user = User.current
        end
      end
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

    # Dump out error messages for a given instance in a single string.  Useful
    # for debugging:
    #
    #   puts user.dump_errors if TESTING
    def dump_errors
      self.formatted_errors.join("; ")
    end

    # List of columns that aren't important enough to cause the +modified+
    # and +user+ fields to be updated.
    UNIMPORTANT_FIELDS = [
      :review_status,
      :reviewer_id,
      :last_review,
      :quality,
      :num_views,
      :last_viewed,
      :last_viewer_id,
    ]

    # This fancy accessor is class-inheritable.  You can set it in any subclass
    # by saying: (the "self" is important!!)
    #
    #   self.extra_unimportant_fields = [...]
    #
    # This will override the default here without unintentionally changing the
    # default for all other subclasses.  Very handy.
    #
    superclass_delegating_accessor :extra_unimportant_fields
    self.extra_unimportant_fields = []

    # "Macro" that lets subclasses add columns to the list of columns that
    # shouldn't cause +modified+ and +user+ to be updated on change.  By
    # default it ignores the view and review stats.
    #
    #   # This is included at the top of the User model:
    #   unimportant_fields :last_login, :last_active
    #
    def self.unimportant_fields(*args)
      self.extra_unimportant_fields = args
    end

    # Have any "important" fields been changed?  Used to determine when to
    # update +modified+ and +user+ fields.
    def important_changes?
      !(changed - UNIMPORTANT_FIELDS - extra_unimportant_fields).empty?
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
    #   user.show_controller => 'observer'
    #   name.show_controller => 'name'
    def show_controller
      case self.class.to_s
        when 'Observation', 'Naming', 'Vote', 'User'
          return 'observer'
        when 'Name', 'SpeciesList', 'Location'
          return self.class.to_s.underscore
        else
          raise(ArgumentError, "Invalid object type, \"#{self.class.to_s.underscore}\".")
      end
    end

    # Return the name of the "show_<object>" action (as a simple
    # lowercase string) that displays this object.
    #
    #   user.show_action => 'show_user'
    #   name.show_action => 'show_name'
    def show_action
      'show_' + self.class.to_s.underscore
    end

################################################################################

  private

    # Need to override this method so that it returns the class just below
    # ActiveRecord::MO, not ActiveRecord::Base.  (This was stolen directly from
    # active_record/base.rb.)
    def self.class_of_active_record_descendant(klass) # :nodoc:
      if klass.superclass == MO || klass.superclass.abstract_class?
        klass
      elsif klass.superclass.nil?
        raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
      else
        class_of_active_record_descendant(klass.superclass)
      end
    end
  end
end
