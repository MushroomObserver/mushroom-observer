#
#  Extensions to ActiveRecord::Base.  This must be required explicitly by any
#  model that needs it.
#
#    after_create     Callback to update SiteData after objects are created.
#    before_destroy   Callback to update SiteData before objects are destroyed.
#
#    obj.formatted_errors   Gather errors for a given instance.
#
################################################################################

module ActiveRecord
  class Base

    # This is called every time an object is created.  It passes off to
    # SiteData, where it will decide whether this affects a user's contribution
    # score, and if so update it appropriately. 
    def after_create; SiteData.update_contribution(:create, self); end

    # This is called every time an object is destroyed.  It passes off to
    # SiteData, where it will decide whether this affects a user's contribution
    # score, and if so update it appropriately. 
    def before_destroy; SiteData.update_contribution(:destroy, self); end

    # This collects all the error messages for a given instance, and returns
    # them as an array of strings, e.g. for flash_notice().  If an error
    # message is a complete sentence (i.e. starts with uppercase) it does
    # nothing with it; otherwise it prepends the class and attribute like this:
    # "is missing" becomes "Object attribute is missing." Errors are created
    # via validates (magically) or by explicit calls to
    #   obj.errors.add(:attr, "message").
    def dump_errors
      self.formatted_errors.join("; ")
    end
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
    #   user.show_action => 'show_user'
    #   name.show_action => 'show_name'
    def show_action
      'show_' + self.class.to_s.underscore
    end
  end
end

