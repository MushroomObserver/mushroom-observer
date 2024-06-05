# frozen_string_literal: true

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

class TranslationString < AbstractModel
  require "acts_as_versioned"

  belongs_to :language
  belongs_to :user

  acts_as_versioned(
    if: :update_version?
  )
  non_versioned_columns.push("tag")

  # Called to determine whether or not to create a new version.
  # Aggregate changes by the same user for up to a day.
  def update_version?
    result = false
    self.user = User.current || User.admin
    self.updated_at = Time.zone.now unless updated_at_changed?
    if text_changed? && text_change[0].to_s != text_change[1].to_s
      latest = versions.latest
      if !latest || # (for testing)
         (latest.updated_at &&
           (latest.user_id != user_id ||
           latest.updated_at < updated_at - 1.day))
        result = true
      elsif latest.text != text || latest.updated_at.to_s != updated_at.to_s
        latest.update(
          text: text,
          updated_at: updated_at
        )
      end
    end
    result
  end

  def self.translations(locale)
    do_init = I18n.backend.translations.empty?
    # rubocop:disable Style/RedundantLineContinuation
    # False positive
    I18n.backend.translations(do_init: do_init) \
      [locale.to_sym][MO.locale_namespace.to_sym]
    # rubocop:enable Style/RedundantLineContinuation
  end

  # Check if tag exists before storing nonsense in the I18n backend
  def update_localization
    data = TranslationString.translations(language.locale.to_sym)
    unless data
      raise(
        "Localization for #{language.locale.inspect} hasn't been loaded yet!"
      )
    end
    unless data[tag.to_sym]
      raise("Localization for :#{tag.to_sym} doesn't exist!")
    end

    store_localization
  end

  # Update this string in the translations I18n is using.
  # Note that our translations are nested under the :mo key!
  def store_localization
    I18n.backend.store_translations(
      language.locale, { mo: { tag.to_sym => text } }
    )
  end

  # Utility method for batch updates. Currently used in tests.
  def self.store_localizations(locale, hash_of_tags_and_texts)
    I18n.backend.store_translations(locale, { mo: hash_of_tags_and_texts })
  end

  # Get age of official language's banner.  (Used by application layout to
  # determine if user has dismissed it yet.)
  def self.banner_time
    find_by(tag: "app_banner_box", language: Language.official).updated_at
  end

  # Call this method from a migration whenever we rename a tag,
  # so we don't lose the existing translation strings.
  def self.rename_tag(old_tag, new_tag)
    # validate that the new tag is snake case maybe, then
    where(tag: old_tag).update_all(tag: new_tag)
  end
end
