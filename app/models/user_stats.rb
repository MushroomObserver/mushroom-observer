# frozen_string_literal: true

# Keep track of each user's contributions
#
#  == Class Methods
#
#  update_contribution::      Callback that keeps User contribution up to date.
#  refresh_all_user_stats::   Callback for cron jobs that refreshes this table.
#
#  ==== Public
#  get_user_data::            Returns stats for given user.
#
#  ==== Private
#  refresh_user_data::        Populates a user_data instance, all columns.
#  refresh_field_count::      Populates a single column in @user_data.
#  calc_metric::              Calculates contribution score of a single user.
#
#
#  == Instance Methods
#
#  sum_bonuses::              Gets the sum of bonuses (a serialized array)
#  update_user_contribution:: Update the associated user.contribution
#
#
#
#  == Internal Data Structure
#
#  The private method load_user_data caches its information in the instance
#  variable +@user_data+.  Its structure is as follows:
#
#    @user_data = {
#      :id         => user.id,
#      :name       => user.unique_text_name,
#      :bonuses    => user.sum_bonuses,
#      :<category> => <num_records_in_category>,
#      :metric     => <weighted_sum_of_category_counts>,
#    }
#
#  == Attributes
#
#  user_id::                User.
#
#  == Counts of records the user has created:
#
#  comments::
#  images::
#  location_description_authors::
#  location_description_editors::
#  locations::
#  locations_versions::
#  name_description_authors::
#  name_description_editors::
#  names::
#  names_versions::
#  namings::
#  observations::
#  sequences::
#  sequenced_observations::
#  species_list_entries::
#  species_lists::
#  translation_strings_versions::
#  votes::
#
#  == Serialized caches for structured data that we don't need to query:
#
#  languages::
#  bonuses::
#  checklists::
#
# rubocop:disable Metrics/ClassLength
class UserStats < ApplicationRecord
  belongs_to :user

  # This causes the data structures in these fields to be serialized
  # automatically with YAML and stored as plain old text strings.
  serialize :languages, type: Hash
  serialize :bonuses
  serialize :checklist, type: Hash

  ALL_FIELDS = {
    name_description_authors: { weight: 100 },
    name_description_editors: { weight: 10 },
    names: { weight: 10 },
    name_versions: { weight: 10 },
    location_description_authors: { weight: 50 },
    location_description_editors: { weight: 5 },
    locations: { weight: 10 },
    location_versions: { weight: 5 },
    images: { weight: 10 },
    species_lists: { weight: 5 },
    species_list_entries: { weight: 1, table: :species_list_observations },
    observations: { weight: 1 },
    sequenced_observations: { weight: 0, table: :sequences },
    sequences: { weight: 0 },
    namings: { weight: 1 },
    comments: { weight: 1 },
    votes: { weight: 1 },
    translation_strings: { weight: 1 },
    languages: { weight: 0, default: {} }
  }.freeze

  # Sum up all the bonuses the User has earned.
  #
  #   contribution += sum_bonuses
  #
  def sum_bonuses
    return nil unless bonuses

    bonuses.inject(0) { |acc, elem| acc + elem[0] }
  end

  class << self
    def fields_with_weight
      ALL_FIELDS.select { |_f, e| e[:weight].positive? }
    end

    # This is called every time any object (not just one we care about) is
    # created or destroyed.  Figure out what kind of object from the class name,
    # and then update the owner's contribution as appropriate.
    #
    # NOTE: This is only approximate.  There are now nontrivial calculations,
    # such as awarding extra points for observations with vouchers, which won't
    # be done right until someone looks at that user's summary page.
    #
    # Two modes:
    # 1) pass in object,
    # NOTE: This is a universal callback on save so `obj` could be anything,
    # including records we don't count
    # 2) pass in field name, when it's not ::model
    def update_contribution(mode, obj, user_id = nil, num = 1)
      if obj.is_a?(ActiveRecord::Base)
        return unless user_id || obj.respond_to?(:user_id)

        field = get_applicable_field(obj)
        user_id ||= obj&.user_id
      else
        return unless user_id || User.current_id

        field = obj
        user_id ||= User.current_id
      end
      weight = ALL_FIELDS.key?(field) ? ALL_FIELDS[field.to_sym][:weight] : 0
      return unless weight&.positive? && user_id&.positive?

      impact = calc_impact(weight * num, mode)
      return if impact.zero?

      User.find(user_id).increment!(:contribution, impact)
      return unless (user_stat = UserStats.find_by(user_id: user_id))

      user_stat.increment!(field, num)
    end

    # impact can be positive or negative
    def calc_impact(weight, mode)
      case mode
      when :del
        -weight
      when :chg
        0
      else
        weight
      end
    end

    # applicable field = affects contribution. NOTE: This is a reverse lookup.
    # Get the key (the `field`) from the value (of :table)
    def get_applicable_field(obj)
      table = obj.class.to_s.tableize.to_sym

      ALL_FIELDS.select { |_f, e| e[:table] == table }.keys.first || table
    end

    ############################################################################
    #
    #    METHODS TO POPULATE OR REFRESH USER_STATS COLUMNS FOR ALL USERS

    # This will create a blank user_stats record (with bonuses, initially)
    # for every contributing user without one. Then, column by column, it
    # calls methods that create a hash of partial user_stats records (containing
    # a single column) keyed by user_id, and merges them column by column
    # until all records have a value for each column except id and user_id.
    # At the end, we find the existing user_stats record id by user_id, and
    # add in the id and user_id, and update all records at once.
    def refresh_all_user_stats
      create_user_stats_for_all_contributors_without
      # `entries` are { user_id: hash_of_attributes }
      # This method fills out the columns for each user_id where not zero.
      # Must set default values for all UserStats attributes here.
      # `upsert_all` requires every record to have ALL the same keys.
      entries = initialize_columns

      # Assemble the new values column by column
      ALL_FIELDS.each_key do |field|
        table = (ALL_FIELDS[field]&.[](:table) || field).to_s

        new_column = case table
                     when "species_list_observations"
                       refresh_species_list_observations
                     when "translation_strings"
                       refresh_translation_strings
                     when "languages"
                       refresh_languages
                     when /^(\w+)_versions/
                       parent_type = $LAST_MATCH_INFO[1]
                       refresh_versions(parent_type, field)
                     else
                       refresh_regular_field(table, field)
                     end
        new_column ||= {}
        entries = entries.deep_merge(new_column)
      end

      # The counters may have added some hashes where it found some user
      # contributions, but the fields are not yet initialized because the
      # user had zero `contribution`. These need to be filled out.
      entries = reinitialize_columns(entries)

      # At this point all these hashes have a user_stats.id and a user_id.
      # It's safe to assume they correspond to existing user_stats records.
      UserStats.upsert_all(entries.values)
    end

    private

    # This runs after the migration, to copy columns from users to user_stats
    # It's a batch insert, so it's fast.
    # TODO: After the initial population, drop the column `bonuses` from User,
    # and remove references to bonuses in `pluck` and the hash here.
    def create_user_stats_for_all_contributors_without
      records = User.where(contribution: 1..).where.missing(:user_stats).
                pluck(:id, :bonuses).map do |id, bonuses|
                  { user_id: id, bonuses: bonuses }
                end

      UserStats.insert_all(records)
    end

    # For each UserStats, build a hash where every column has a default value.
    # Make `user_id` the first column, because we're updating on that.
    def initialize_columns
      UserStats.pluck(:user_id).to_h do |user_id|
        init = { user_id: user_id }
        columns = ALL_FIELDS.keys.index_with do |field|
          ALL_FIELDS[field][:default] || 0
        end
        [user_id, init.merge(columns)]
      end
    end

    # Exception for species_list_entries:
    def refresh_species_list_observations
      results = SpeciesList.joins(:species_list_observations).
                group(:user_id).distinct.
                select(:user_id, Arel.star.count.as("cnt"))

      results.to_h do |record|
        [record.user_id, { species_list_entries: record.cnt }]
      end
    end

    # Exception for versions: Corrects for double-counting of versioned records.
    # NOTE: arel_table[:column].count(true) means "COUNT DISTINCT column"
    def refresh_versions(parent_type, field)
      parent_class = parent_type.classify.constantize
      version_class = "#{parent_class}::Version".constantize
      parent_id = "#{parent_type}_id"

      results = version_class.joins(:"#{parent_type}").
                where.not(
                  version_class.arel_table[:user_id].eq(parent_class[:user_id])
                ).group(:user_id).select(
                  :user_id,
                  version_class.arel_table[:"#{parent_id}"].
                  count(true).as("cnt")
                )

      results.to_h do |record|
        [record.user_id, { "#{field}": record.cnt }]
      end
    end

    # Regular counts keyed by user_id:
    def refresh_regular_field(table, field)
      field_class = table.to_s.classify.constantize

      results = field_class.group(:user_id).distinct.
                select(:user_id, Arel.star.count.as("cnt"))

      results.to_h do |record|
        [record.user_id, { "#{field}": record.cnt }]
      end
    end

    def refresh_translation_strings
      # Skipping `language_id` gives total translation_string counts per user
      all = TranslationString::Version.where.not(language_id: nil).
            select(
              :user_id,
              TranslationString::Version.arel_table[:translation_string_id].
              count(true).as("cnt")
            ).group(:user_id)

      all.to_h do |record|
        [record.user_id, { translation_strings: record.cnt }]
      end
    end

    def refresh_languages
      locale_index = Language.pluck(:id, :locale).to_h

      # JSON_OBJECTAGG returns a suitable object for this column, after parsing.
      # Note selecting/grouping :language_id gives a separate AR record per lang
      # but then you need to aggregate those by user_id
      statement = <<-SQL.squish
      SELECT user_id, JSON_OBJECTAGG(language_id, n)
      FROM (
        SELECT user_id, language_id, COUNT(DISTINCT translation_string_id) as n
        FROM translation_string_versions
        WHERE language_id IS NOT NULL
        GROUP BY user_id, language_id
      ) x
      GROUP BY user_id
      SQL
      by_lang = TranslationString::Version.connection.execute(statement)

      # Set languages hash for each user_id.
      # Note query returns arrays of arrays: `[[user_id: lang_hash]]`
      # Here's a sample value:
      #   [11038, {12: 1617}],
      # Inside the hash, we want to convert the `language_id` keys to locales.
      by_lang.to_h do |result|
        hash_by_ids = JSON.parse(result[1])
        hash_by_locales = hash_by_ids.transform_keys do |key|
          locale_index[key.to_i]
        end
        [result[0], { languages: hash_by_locales }]
      end
    end

    # For each record we're about to update, check for incomplete entries that
    # the counters may have added. Move the :user_id to the front of the hash
    # and fill out the rest of the attributes with defaults.
    def reinitialize_columns(entries)
      # Cheat: uninitialized entries won't have `user_stats.id`
      needs_id = entries.select do |_user_id, values|
        values[:id].nil?
      end

      rebuilt_entries = needs_id.to_h do |user_id, values|
        rebuilt_hash = { user_id: user_id }
        columns = ALL_FIELDS.keys.index_with do |field|
          values[field] || ALL_FIELDS[field][:default] || 0
        end
        rebuilt_hash = rebuilt_hash.merge(columns)

        # Should update the user.contribution,
        # because this means we missed it and it's out of whack.
        @user_data = UserStats.new(rebuilt_hash)
        @user_data.update_user_contribution

        [user_id, rebuilt_hash]
      end

      entries.merge(rebuilt_entries)
    end
  end

  ##############################################################################
  #
  #    METHODS TO REFRESH USER_STATS COLUMNS FOR A SINGLE USER

  # Return stats for a single User. This can be run on demand.
  # Returns simple hash mapping category to number of records of that category.
  #
  #   data = UserStats.new.get_user_data(user_id)
  #   num_images = data[:images]
  #
  def self.get_user_data(user_id)
    @user_stats = UserStats.find_by(user_id: user_id) ||
                  UserStats.new(user_id: user_id)
    @user_stats.refresh_user_data(user_id)
    @user_stats
  end

  private

  #   Refresh all the stats for a given UserStats instance.
  #
  #   refresh_user_data(user.id)
  #   user.contribution = @user_data[:metric]
  #
  def refresh_user_data(user_id = nil)
    return unless user_id

    user = User.find(user_id)

    # Prime @user_data structure.
    @user_data ||= {}
    @user_data = {
      id: user_id,
      name: user.unique_text_name
    }

    # Refresh record counts for each category of @user_data.
    ALL_FIELDS.each_key { |field| refresh_field_count(field, user_id) }

    # Update the UserStats record in one go.
    update(@user_data.except(:id, :name))

    update_user_contribution
  end

  # Do a query to get the number of records in a given category for a User.
  # This is cached in @user_data.
  #
  #   # Get number of images for current user.
  #   refresh_field_counts(:images, User.current.id)
  #   num_images = @user_data[:images]
  #
  def refresh_field_count(field, user_id = nil)
    return unless user_id

    table = (ALL_FIELDS[field][:table] || field).to_s

    count = case table
            when "species_list_observations"
              count_species_list_observations(user_id)
            when "translation_strings"
              count_translation_strings(user_id, by_lang: false)
            when "languages"
              count_translation_strings(user_id, by_lang: true)
            when /^(\w+)_versions/
              parent_type = $LAST_MATCH_INFO[1]
              count_versions(parent_type, user_id)
            else
              count_regular_field(table, user_id)
            end

    @user_data[field] = count
  end

  # Exception for species_list_entries, does a simple join:
  def count_species_list_observations(user_id)
    SpeciesList.joins(:species_list_observations).where(user_id: user_id).count
  end

  def count_translation_strings(user_id, by_lang: false)
    results = translation_strings_for_user(user_id)

    if by_lang
      results
    else
      results.values.sum
    end
  end

  # Skip orphaned translation strings(?) with `nil` as their language id
  def translation_strings_for_user(user_id)
    locale_index = Language.pluck(:id, :locale).to_h

    all = TranslationString::Version.where(user_id: user_id).
          where.not(language_id: nil).
          select(
            :language_id,
            TranslationString::Version.arel_table[:translation_string_id].
            count(true).as("cnt")
          ).group(:language_id)

    # Turn it into a hash of translation strings by locale.
    all.to_h do |lang|
      [locale_index[lang.language_id], lang.cnt]
    end
  end

  # This counts versions where the editor was not the original author
  # Should correct for the double-counting of created records
  # NOTE: the version classes need `.arel_table`, unlike other models
  def count_versions(parent_type, user_id)
    parent_class = parent_type.classify.constantize
    version_class = "#{parent_class}::Version".constantize
    parent_id = "#{parent_type}_id"

    version_class.joins(:"#{parent_type}").
      where(version_class.arel_table[:user_id].eq(user_id)).
      where.not(
        version_class.arel_table[:user_id].eq(parent_class[:user_id])
      ).distinct.select(version_class.arel_table[:"#{parent_id}"]).count
  end

  # Regular count, by :user_id
  def count_regular_field(table, user_id)
    field_class = table.to_s.classify.constantize

    field_class.where(user_id: user_id).count
  end

  # Update the user contribution based on a UserStats instance
  # Be sure to set @user_data = UserStats.new(attributes) before calling this
  def update_user_contribution
    # Calculate full contribution for each user.
    contribution = calc_metric(@user_data)
    # Make sure contribution caches are correct.
    return unless user.contribution != contribution

    user.update(contribution: contribution)
  end

  # Calculate score for a set of results:
  #
  #   score = calc_metric(
  #     images:        10,
  #     observations:  10,
  #     comments:      23,
  #     species_lists: 1,
  #     ...
  #   )
  #
  # :doc:
  def calc_metric(data)
    metric = 0
    return metric unless data

    ALL_FIELDS.each do |field, entry|
      next unless data[field]

      # This fixes the double-counting of created records.
      if field.to_s =~ /^(\w+)_versions$/
        data[field] -= data[Regexp.last_match(1)] || 0
      end
      metric += entry[:weight] * data[field]
    end
    # metric += data[:languages].to_i
    metric += sum_bonuses.to_i
    data[:metric] = metric
    metric
  end
end
# rubocop:enable Metrics/ClassLength
