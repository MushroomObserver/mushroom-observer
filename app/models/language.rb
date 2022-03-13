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
  require "arel-helpers"

  include ArelHelpers::ArelTable
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
    id_select_manager = arel_select_top_contributors_ids(num)
    # puts(id_select_manager.to_sql)
    user_ids = self.class.connection.select_values(id_select_manager.to_sql)
    # puts(user_ids.inspect)
    if user_ids.any?
      user_select_manager = arel_select_top_contributors_in_order(user_ids)
      user_ids = self.class.connection.select_rows(user_select_manager.to_sql)
      # puts(user_ids.inspect)
    end
    user_ids
  end

  private

  # SELECT user_id
  # FROM translation_strings
  # WHERE language_id = #{id} AND user_id != 0
  # GROUP BY user_id
  # ORDER BY COUNT(id) DESC
  # LIMIT #{num}
  def arel_select_top_contributors_ids(num)
    t = TranslationString.arel_table
    t.project(t[:user_id]).
      where(t[:language_id].eq(id).and(t[:user_id].not_eq(0))).
      group(t[:user_id]).order(t[:id].count.desc).take(num)
  end

  # SELECT id, login
  # FROM users
  # WHERE id IN (#{user_ids.join(",")})
  # ORDER BY FIND_IN_SET(id, '#{user_ids.join(",")}')
  # Note: ORDER BY unnecessary? `project` by id seems to maintain the order.
  def arel_select_top_contributors_in_order(user_ids)
    u = User.arel_table
    u.project([u[:id], u[:login]]).where(u[:id].in(user_ids))
  end

  public

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
    # puts(select_manager.to_sql)
    values = Language.connection.select_values(select_manager.to_sql)
    # puts(values.inspect)
    for text in values
      lines += Language.score_lines(text)
    end
    lines
  end

  private

  # SELECT GROUP_CONCAT(CONCAT(v.text, "\n")) AS x
  # FROM translation_strings t, translation_strings_versions v
  # WHERE t.language_id = #{id}
  #   AND v.translation_string_id = t.id
  #   AND v.user_id = #{user.id}
  # GROUP BY t.id
  def arel_select_translation_strings(user)
    t = Arel::Table.new(:translation_strings)
    v = Arel::Table.new(:translation_strings_versions)
    TranslationString.joins(t.join(v).on(t[:language_id].eq(id).
                            and(v[:translation_string_id].eq(t[:id])).
                            and(v[:user_id].eq(user.id))).join_sources).
      group(t[:id]).select(self.class.arel_function_group_concat_strings(v))
  end

  public

  def self.arel_function_group_concat_strings(v)
    Arel::Nodes::NamedFunction.new(
      "GROUP_CONCAT",
      [Arel::Nodes::NamedFunction.new(
        "CONCAT",
        [v[:text],
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
    select_manager = arel_select_recent_translations
    strings = Language.connection.select_rows(select_manager.to_sql)

    for locale, tag, text in strings
      TranslationString.translations(locale.to_sym)[tag.to_sym] = text
    end
  end

  # SELECT locale, tag, text
  # FROM translation_strings t, languages l
  # WHERE t.language_id = l.id
  #   AND t.updated_at >= #{Language.connection.quote(cutoff)}
  private_class_method def self.arel_select_recent_translations
    cutoff = @@last_update
    @@last_update = Time.zone.now
    update_cutoff = Language.connection.quote(cutoff)
    lang = Language.arel_table
    ts = TranslationString.arel_table

    ts.project([lang[:locale], ts[:tag], ts[:text]]).
      join(lang).on(ts[:language_id].eq(lang[:id]).
                    and(ts[:updated_at].gteq(update_cutoff)))
  end
end
