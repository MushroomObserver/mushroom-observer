module ActiveRecord
  module Acts
    module Versioned
      module ActMethods

        # Save changes in an Object.  This will create a PastObject if there
        # are signficant changes (automatically done by callbacks associated
        # with save method).  It will also set the user, modification time, and
        # log an optional message if there are any changes to save.  NOTE: it
        # will not log anything if it's a new record.
        #
        #   object = Object.find(id) or Object.new
        #   object.blah = blah
        #   object.save_if_changed(user, "#{user.login} changed blah")
        #
        # Pass in the timestamp if you are changing multiple objects and want
        # them all to have the exact same timetstamp.  Defaults to now. 
        #
        # Returns true if there were changes and it successfully saved them.
        # Check object.errors on false to see if it failed due to errors.
        # Otherwise you can assume there were no changes to save.
        #
        def save_if_changed(user=nil, log=nil, time=nil)
          result = false
          if self.new_record?
# print ">>>>>>>> New #{self.class}: ##{self.id} #{self.text_name}\n"
            self.user = user if user
            result = self.save
          elsif self.altered?
# print ">>>>>>>> Altered #{self.class}: ##{self.id} #{self.text_name}\n"
            self.modified = time || Time.now
            self.user = user if user
            result = self.save
            self.log(log) if result && log 
          elsif self.changed?
# print ">>>>>>>> Changed #{self.class}: ##{self.id} #{self.text_name}\n"
            self.modified = time || Time.now
            result = self.save
          else
            # do nothing
# print ">>>>>>>> Unchanged #{self.class}: ##{self.id} #{self.text_name}\n"
          end
          return result
        end

      end

      module ClassMethods

        # Sets the :if_changed attribute of acts_as_versioned by telling it
        # which attributes *not* to pay attention to.  Note it will still save
        # these in past_objects table, but something else will have to be
        # changed before it will do so. 
        #
        #   class Thingy < ActiveRecord::Base
        #     acts_as_versioned
        #     non_versioned_columns << 'hidden_column'
        #     ignore_if_changed('modified', 'user_id')
        #
        # NOTE: be sure to set non_versioned_columns first!
        #
        def ignore_if_changed(*args)
          self.track_altered_attributes = true
          self.version_if_changed = self.column_names - self.non_versioned_columns - args
        end
      end
    end
  end
end
