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
    TranslationString.where(language: self).where.not(user_id: 0).
      group(:user_id).order(TranslationString[:id].count).limit(num).
      joins(:user).pluck(User[:id], User[:login])
  end

  # Count the number of lines the user has translated.  Include edits, as well.
  # It counts paragraphs, actually, and weights them according to length.
  def self.calculate_users_contribution(user)
    lines = 0
    select_manager = arel_select_translation_strings_versions(user)
    # puts(select_manager.to_sql)
    values = Language.connection.select_values(select_manager.to_sql)
    # # puts(values.inspect)
    for text in values
      lines += score_lines(text)
    end
    lines
  end

  # SELECT GROUP_CONCAT(CONCAT(text, "\n")) AS x
  # FROM translation_strings_versions
  # WHERE user_id = #{user.id}
  # GROUP BY translation_string_id
  private_class_method def self.arel_select_translation_strings_versions(user)
    v = Arel::Table.new(:translation_strings_versions)
    v.where(v[:user_id].eq(user.id)).
      group(v[:translation_string_id]).
      project(arel_function_group_concat_strings(v))
  end

  def calculate_users_contribution(user)
    lines = 0
    select_manager = arel_select_translation_strings(user)
    values = Language.connection.select_values(select_manager.to_sql)
    for text in values
      lines += Language.score_lines(text)
    end
    lines
  end

  # def calculate_users_contribution(user)
  #   v = Arel::Table.new(:translation_strings_versions)
  #   hash = {}
  #   strings = TranslationString.joins(:versions).
  #             where(language_id: id,
  #                   translation_strings_versions: { user_id: user.id }).
  #             group(:id).pluck(:id, v[:text])
  #   strings.each do |id, text|
  #     text.split("\n").each do |str|
  #       (hash[id] ||= {}) && (hash[id][str] = true) if str.present?
  #     end
  #     puts(hash)
  #   end
  #   score_lines(hash)
  # end

  # def score_lines(hash)
  #   score = 0
  #   hash.each_value do |hash2|
  #     hash2.each_key do |key|
  #       score += (key.length.to_f / CHARACTERS_PER_LINE).truncate + 1
  #     end
  #   end
  #   score
  # end

  # SELECT GROUP_CONCAT(CONCAT(v.text, "\n")) AS x
  # FROM translation_strings t, translation_strings_versions v
  # WHERE t.language_id = #{id}
  #   AND v.translation_string_id = t.id
  #   AND v.user_id = #{user.id}
  # GROUP BY t.id
  # rubocop:disable Metrics/AbcSize
  def arel_select_translation_strings(user)
    t = Arel::Table.new(:translation_strings)
    v = Arel::Table.new(:translation_strings_versions)
    TranslationString.joins(t.join(v).on(t[:language_id].eq(id).
                            and(v[:translation_string_id].eq(t[:id])).
                            and(v[:user_id].eq(user.id))).join_sources).
      group(t[:id]).select(self.class.arel_function_group_concat_strings(v))
  end
  # rubocop:enable Metrics/AbcSize

  # NIMMO QUESTION - Is there a way to rewrite these without the group_concat?
  # I was thinking maybe just select the :text, and append the newlines in Ruby
  # via map. But this gives a different score, because of the grouping.
  # The command in PostgresQL is "STRING_AGG"
  def self.arel_function_group_concat_strings(table)
    Arel::Nodes::NamedFunction.new(
      "GROUP_CONCAT",
      [Arel::Nodes::NamedFunction.new(
        "CONCAT",
        [table[:text],
         Arel::Nodes.build_quoted("\n")]
      )]
    )
  end

  def self.score_lines(text)
    hash = {}
    for str in text.split("\n")
      hash[str] = true if str.present?
    end
    score = 0
    for key in hash.keys
      score += (key.length.to_f / CHARACTERS_PER_LINE).truncate + 1
    end
    score
  end

  # Be generous to ensure that we don't accidentally miss anything that is
  # changed while the Rails app is booting.
  @@last_update = 1.minute.ago

  # Update I18n backend with any recent changes in translations.
  def self.update_recent_translations
    cutoff = @@last_update
    @@last_update = Time.zone.now
    strings = TranslationString.joins(:language).
              where(TranslationString[:updated_at].gteq(cutoff)).
              pluck(Language[:locale], :tag, :text)

    for locale, tag, text in strings
      TranslationString.translations(locale.to_sym)[tag.to_sym] = text
    end
  end
end
