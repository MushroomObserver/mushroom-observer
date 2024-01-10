# frozen_string_literal: true

module Name::Resolve
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  def save_with_log(log = nil, args = {})
    return false unless changed?

    log ||= :log_name_updated
    args = { touch: altered? }.merge(args)
    return false unless save

    log(log, args)
    true
  end

  module ClassMethods
    def create_needed_names(input_what, output_what = nil)
      names = []
      if output_what.nil? || input_what == output_what
        names = find_or_create_name_and_parents(input_what)
        if names.last
          names.each do |n|
            next unless n&.new_record?

            n.inherit_stuff
            n.save_with_log(:log_updated_by)
          end
        end
      end
      names.last
    end

    def save_names(names, deprecate)
      log = nil
      unless deprecate.nil?
        log = if deprecate
                :log_deprecated_by
              else
                :log_approved_by
              end
      end
      names.each do |n|
        next unless n&.new_record?

        n.change_deprecated(deprecate) if deprecate
        n.inherit_stuff
        n.save_with_log(log)
      end
    end

    # A common mistake is capitalizing the species epithet. If the second word
    # is capitalized, and the name isn't recognized if the second word is
    # interpreted as an author, and it *is* recognized if changed to lowercase,
    # this method changes the second word to lowercase.  Returns fixed string.
    def fix_capitalized_species_epithet(str)
      # Is second word capitalized?
      return str unless str.match?(/^\S+ [A-Z]/)

      # Trust it if there is actually a name with that author present.
      return str if Name.find_by(search_name: str).present?

      # Try converting second word to lowercase.
      str2 = str.sub(/ [A-Z]/, &:downcase)

      # Return corrected name if that name exists, else keep original name.
      if Name.where(search_name: str2).or(Name.where(text_name: str2)).present?
        str2
      else
        str
      end
    end
  end
end
