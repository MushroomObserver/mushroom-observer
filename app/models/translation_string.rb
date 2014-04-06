# encoding: utf-8
#
#  = TranslationString
#
#  Contains a single localization string.
#
#  == Attributes
#
#  language::    Language it belongs to.
#  tag::         Globalite "tag", e.g., :app_title.
#  text::        The actual text, e.g., "Mushroom Observer".
#  version::     ActsAsVersioned version number.
#  updated_at::  DateTime it was last updated.
#  user::        User who last updated it.
#
#  == Versions
#
#  ActsAsVersioned tracks changes in +text+, +updated_at+, and +user+.
#
################################################################################

require 'acts_as_versioned'

class TranslationString < AbstractModel
  belongs_to :language
  belongs_to :user

  acts_as_versioned(
    :table_name => 'translation_strings_versions',
    :if => :update_version?
  )
  non_versioned_columns.push('language_id', 'tag')

  # Called to determine whether or not to create a new version.
  # Aggregate changes by the same user for up to a day.
  def update_version?
    result = false
    self.user = User.current || User.admin
    self.updated_at = Time.now unless updated_at_changed?
    if text_changed? and text_change[0].to_s != text_change[1].to_s
      latest = versions.latest
      if not latest or # (for testing)
        (latest.updated_at and
          (latest.user_id != user_id or
          latest.updated_at < updated_at - 1.day))
        result = true
      elsif latest.text != text or latest.updated_at.to_s != updated_at.to_s
        latest.update_attributes(
          :text => text,
          :updated_at => updated_at
        )
      end
    end
    return result
  end

  # Update this string in the current set of translations Globalite is using.
  def update_localization
    data = Globalite.localization_data[language.locale.to_sym]
    raise "Localization for #{language.locale.inspect} hasn't been loaded yet!" unless data
    data[tag.to_sym] = text
  end
end
