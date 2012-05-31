# encoding: utf-8
#
#  = TranslationString
#
#  Contains a single localization string.
#
#  == Attributes
#
#  language::   Language it belongs to.
#  tag::        Globalite "tag", e.g., :app_title.
#  text::       The actual text, e.g., "Mushroom Observer".
#  version::    ActsAsVersioned version number.
#  modified::   DateTime it was last modified.
#  user::       User who last modified it.
#
#  == Versions
#
#  ActsAsVersioned tracks changes in +text+, +modified+, and +user+.
#
################################################################################

class TranslationString < AbstractModel
  belongs_to :language
  belongs_to :user

  acts_as_versioned(
    :table_name => 'translation_strings_versions',
    :if_changed => [ 'text' ]
  )
  non_versioned_columns.push('language_id', 'tag')

  before_update do |record|
    record.user = User.current || User.find(0)
  end

  # Update this string in the current set of translations Globalite is using.
  def update_localization
    old_locale = Locale.code
    new_locale = language.locale
    if old_locale.to_s != new_locale.to_s
      # I'd rather not switch locales frequently.  That seems an invitation
      # for abuse in case the caller wants to update lots of strings.  Setting
      # Locale.code is not very efficient.  I'd rather force the caller to
      # change locale themselves, then call this method as much as they like.
      raise "Trying to update #{new_locale} when #{old_locale} is current!"
    end
    Globalite.localizations[tag.to_sym] = text
  end
end

