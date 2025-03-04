# frozen_string_literal: true

#
#  = Language
#
#  This model groups all the translations for a single locale.
#
#  == Attributes
#
#  locale::  Official locale string, e.g., "en".
#  name::    Name of the language in that language, e.g., "English" or "Español"
#  order::   Latinized version language name, e.g., "Russkii" or "Ellenika"
#  official::   Set to true for English: this is the fall-back language
#               for missing translations.
#  beta::  If true, this will not be shown in the list of available languages
#
#  == Localization and export files
#
#  Translation strings are exported to two sets of files.  See LanguageExporter
#  module for more information.
#
#  == Tracking translations used on a page
#
#  Very simple global mechanism for keeping track of which localization strings
#  are used on each page.  See LanguageTracking module for more info.
#
################################################################################

class Language < AbstractModel
  include LanguageExporter
  class << self
    include LanguageTracking
  end

  has_many :translation_strings, dependent: :destroy

  # Average characters per line; used to score contributions.
  CHARACTERS_PER_LINE = 80

  # Look up the official Language.
  def self.official
    find_by_official(true)
  end

  # Return Array of unofficial Language's.
  def self.unofficial
    where(official: false)
  end

  # Returns an Array of pairs containing language name and locale.
  # Useful for building pulldown menus using <tt>select_tag</tt> helper.
  def self.menu_options
    all.sort_by(&:order).map do |lang|
      [lang.name, lang.locale]
    end
  end

  # Get a list of the top N contributors to a language's translations.
  # This is used by the app layout, so must cause mimimal database load.
  def top_contributors(num = 10)
    TranslationString.
      # includes([:user]).
      where(language: self).where.not(user_id: 0).
      group(:user_id).
      order(TranslationString[:id].count).
      limit(num).
      joins(:user).
      pluck(User[:id], User[:login])
  end

  # Count the number of lines the user has translated.  Include edits, as well.
  # It counts paragraphs, actually, and weights them according to length.
  def self.calculate_users_contribution(user)
    lines = 0
    contributions = get_user_translation_contributions_overall(user)
    contributions.pluck(:text).each do |text|
      lines += score_lines(text)
    end
    lines
  end

  private_class_method def self.get_user_translation_contributions_overall(user)
    v = Arel::Table.new(:translation_string_versions)
    TranslationString::Version.
      where(user_id: user.id).
      group(:translation_string_id).
      select(v[:text].group_concat("\n", order: [v[:text].asc]))
  end

  # For one language (instance method)
  def calculate_users_contribution(user)
    lines = 0
    contributions = get_user_translation_contributions(user)
    contributions.pluck(:text).each do |text|
      lines += Language.score_lines(text)
    end
    lines
  end

  def get_user_translation_contributions(user)
    v = Arel::Table.new(:translation_string_versions)
    TranslationString.
      # includes([:user, :versions]).
      joins(:versions).
      where(language_id: id).
      where(v[:user_id].eq(user.id)).
      group(:id).
      select(v[:text].group_concat("\n", order: [v[:text].asc]))
  end

  def self.score_lines(text)
    hash = {}
    text.split("\n").each do |str|
      hash[str] = true if str.present?
    end
    score = 0
    hash.each_key do |key|
      score += (key.length.to_f / CHARACTERS_PER_LINE).truncate + 1
    end
    score
  end

  # Be generous to ensure that we don't accidentally miss anything that is
  # changed while the Rails app is booting.
  # We need a class variable here
  @@last_update = 1.minute.ago
end
