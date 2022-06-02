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
  after_create :store_localization
  before_update :update_localization

  acts_as_versioned(
    table_name: "translation_strings_versions",
    if: :update_version?
  )
  non_versioned_columns.push(
    "language_id",
    "tag"
  )

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
    I18n.backend.translations[locale.to_sym][MO.locale_namespace.to_sym]
    # I18n.backend.load_translations if I18n.backend.send(:translations).empty?
    # I18n.backend.send(:translations)[locale.to_sym]\
    #   [MO.locale_namespace.to_sym]
  end

  # Update this string in the translations I18n is using.
  def store_localization
    I18n.backend.store_translations(language.locale, { tag.to_sym => text })
    # I18n.backend.reload! # No, this will reload the yml
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

    # data[tag.to_sym] = text
    # In Ruby 3.0, the data hash is frozen and cannot be modified.
    # The I18n gem, though, has a method to do this (dup'ing the hash)
    # I18n.backend.store_translations(language.locale, { tag.to_sym => text })
    store_localization
  end

  # Get age of official language's banner.  (Used by application layout to
  # determine if user has dismissed it yet.)
  def self.banner_time
    find_by(tag: "app_banner_box", language: Language.official).updated_at
  end
end
