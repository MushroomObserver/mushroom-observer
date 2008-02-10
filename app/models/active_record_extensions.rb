#
#  Extend ActiveRecord class.
#
#  smart_find_id(id)        Look up ID and give smart error message if fails.
#  obj.formatted_errors     Gather errors for a given instance.
#  attr_display_names       Override method names in error messages.
#
################################################################################

module ActiveRecord
  class Base

    # This just does a generic ID look-up with an intelligent error message.
    # (Which file am I supposed to put this stupid thing in, anyway??)
    def self.smart_find_id(id)
      begin
        return self.find(id)
      rescue ActiveRecord::RecordNotFound
        # Not quite sure what to do at this point other than raise another error!
        raise "Invalid #{self.to_s} id: '#{id}'"
      end
    end

    # This collects all the error messages for a given instance, and returns
    # them as an array of strings, e.g. for flash_notice().  If an error
    # message is a complete sentence (i.e. starts with uppercase) it does
    # nothing with it; otherwise it prepends the class and attribute like this:
    # "is missing" becomes "Object attribute is missing." Errors are created
    # via validates (magically) or by explicit calls to
    #   obj.errors.add(:attr, "message").
    def formatted_errors
      out = []
      self.errors.each { |attr, msg|
        if msg.match(/^[A-Z]/)
          out << msg
        else
          name = self.class.get_attr_display_names[attr.to_s].to_s
          if name.nil? || name == ""
            name = attr.to_s.gsub(/_/, " ")
          end
          obj = self.class.to_s.gsub(/_/, " ")
          out << "#{obj} #{name} #{msg}."
        end
      }
      return out
    end

    # Override attribute names in error and warning messages.
    #   attr_display_names({
    #     :attribute => "display name",
    #     :attribute => "display name",
    #     ...
    #   })
    def self.attr_display_names(hash)
      class_eval(<<-EOS)
        def self.get_attr_display_names
          { #{ hash.keys.map { |k| "'#{k.to_s}'=>'#{hash[k].to_s}'" }.join(",") } }
        end
      EOS
    end

    # Don't override anything by default.
    def self.get_attr_display_names
      {}
    end
  end
end

