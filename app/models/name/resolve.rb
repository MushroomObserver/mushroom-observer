# frozen_string_literal: true

module Name::Resolve
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  def save_with_log(user, log_tag = nil, args = {})
    return false unless changed?

    log_tag ||= :log_name_updated
    args = { touch: altered? }.merge(args)
    first_version_for_user = new_version_for_user?(user.id)
    @current_user = user
    return false unless save

    award_version_contribution(user.id) if first_version_for_user
    log(log_tag, user: user, **args)
    true
  end

  # True if `user_id` has no existing version row for this Name yet -
  # used to decide whether to award a "first time editing this name"
  # contribution point. Must run BEFORE save: VersionedByCurrentUser's
  # after_save hook writes the new version's user_id immediately, so
  # checking this after save would always self-match and return false.
  def new_version_for_user?(user_id)
    Name::Version.where(name_id: id, user_id: user_id).none?
  end

  def award_version_contribution(user_id)
    ver = Name::Version.where(name_id: id).last
    return if ver.version == 1

    UserStats.update_contribution(:add, :name_versions, user_id)
  end

  module ClassMethods
    def create_needed_names(user, input_what, output_what = nil)
      names = []
      if output_what.nil? || input_what == output_what
        names = find_or_create_name_and_parents(user, input_what)
        return nil if names.last && !update_and_save_names(user, names)
      end
      names.last
    end

    def update_and_save_names(user, names)
      names.each do |n|
        next unless n&.new_record?

        n.inherit_stuff
        return false unless n.save_with_log(user, :log_updated_by)
      end
      true
    end

    def save_names(user, names, deprecate)
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
        n.save_with_log(user, log)
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
      if Name.where(search_name: str2).
         or(Name.where(text_name: str2)).present?
        str2
      else
        str
      end
    end
  end
end
