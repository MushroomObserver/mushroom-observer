# frozen_string_literal: true

# Keep track of each user's contributions
#
#  == Class Methods
#
#  update_contribution::    Callback that keeps User contribution up to date.
#
#  ==== Public
#  get_user_data::          Returns stats for given user.
#
#  ==== Private
#  refresh_user_data::      Populates a user_data instance, all columns.
#  refresh_field_count::    Populates a single column in @user_data.
#  calc_metric::            Calculates contribution score of a single user.
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

class UserStats < ApplicationRecord
  belongs_to :user

  # This causes the data structures in these fields to be serialized
  # automatically with YAML and stored as plain old text strings.
  serialize :languages, type: Hash
  # TODO:
  # 1. copy user.bonuses to user_stats.bonuses after records created
  # 2. switch `refresh_user_data` to use the method below
  serialize :bonuses

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
    translation_string_versions: { weight: 1 }
  }.freeze

  def self.fields_with_weight
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
  def self.update_contribution(mode, obj, user_id = nil, num = 1)
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
  def self.calc_impact(weight, mode)
    case mode
    when :del
      -weight
    when :chg
      0
    else
      weight
    end
  end

  # An applicable field = affects contribution. NOTE: This is a reverse lookup.
  # Get the key (the `field`) from the value (of :table)
  def self.get_applicable_field(obj)
    table = obj.class.to_s.tableize.to_sym

    ALL_FIELDS.select { |_f, e| e[:table] == table }.keys.first || table
  end

  # Return stats for a single User.  Returns simple hash mapping category to
  # number of records of that category.
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

  ##############################################################################

  # Refresh all the stats for a given User.
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
      name: user.unique_text_name,
      languages: language_contributions(user_id),
      # temporary: copy over bonuses from User object.
      # TODO: remove this line after initial population.
      bonuses: user.bonuses
    }

    # Refresh record counts for each category of @user_data.
    ALL_FIELDS.each_key { |field| refresh_field_count(field, user_id) }

    # Update the UserStats record in one go.
    update(@user_data.except(:id, :name))

    # Calculate full contribution for each user.
    contribution = calc_metric(@user_data)
    # Make sure contribution caches are correct.
    return unless user.contribution != contribution

    user.update(contribution: contribution)
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
            when /^(\w+)_versions/
              parent_table = $LAST_MATCH_INFO[1]
              count_versions(parent_table, user_id)
            else
              count_regular_field(table, user_id)
            end

    @user_data[field] = count
  end

  # Exception for species_list_entries, does a simple join:
  def count_species_list_observations(user_id)
    SpeciesList.joins(:species_list_observations).where(user_id: user_id).count
  end

  # This counts versions where the editor was not the original author
  # Should correct for the double-counting of created records
  # NOTE: the version classes need `.arel_table`, unlike other models
  def count_versions(parent_table, user_id)
    parent_class = parent_table.classify.constantize
    version_class = "#{parent_class}::Version".constantize
    parent_id = "#{parent_table}_id"

    parent_class.joins(:versions).
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

  # NOTE: These do not count towards the metric.
  def language_contributions(user_id)
    locale_index = Language.pluck(:id, :locale).to_h

    orig = TranslationString.where(user_id: user_id).
           select(:language_id, Arel.star.count.as("cnt")).
           group(:language_id).order(cnt: :desc)

    # Turn it into a hash of translation strings by locale.
    counts_orig = orig.to_h do |lang|
      [locale_index[lang.language_id], lang.cnt]
    end

    vers =
      TranslationString.joins(:versions).
      where(TranslationString::Version.arel_table[:user_id].eq(user_id)).
      where.not(
        TranslationString::Version.arel_table[:user_id].eq(
          TranslationString[:user_id]
        )
      ).distinct.select(:language_id, Arel.star.count.as("cnt")).
      group(:language_id).order(cnt: :desc)

    # Turn it into a hash of translation strings by locale.
    counts_vers = vers.to_h do |lang|
      [locale_index[lang.language_id], lang.cnt]
    end

    # Merges the values, whether or not the key is present both places
    counts_orig.merge(counts_vers) { |_key, orig_v, vers_v| orig_v + vers_v }
  end

  # Sum up all the bonuses the User has earned.
  #
  #   contribution += sum_bonuses
  #
  def sum_bonuses
    return nil unless bonuses

    bonuses.inject(0) { |acc, elem| acc + elem[0] }
  end

  ##############################################################################
  #
  #    METHODS TO POPULATE OR REFRESH USER_STATS COLUMNS FOR ALL USERS

  # Each of these methods creates a hash of partial records (a single column)
  # keyed by user_id. At the bottom it finds or initializes the record by
  # user_id, and updates all columns at once.
  def self.refresh_all_user_stats
    records = {}
    ALL_FIELDS.each_key do |field|
      table = (ALL_FIELDS[field]&.[](:table) || field).to_s

      new_column = case table
                   when "species_list_observations"
                     refresh_species_list_observations
                   when /^(\w+)_versions/
                     parent_table = $LAST_MATCH_INFO[1]
                     refresh_versions(parent_table)
                   else
                     refresh_regular_field(table, field)
                   end
      new_column ||= {}
      records = records.deep_merge(new_column)
    end

    records.each do |user_id, columns|
      UserStats.find_or_initialize_by(user_id: user_id).update(columns)
    end
  end

  # Exception for species_list_entries:
  def self.refresh_species_list_observations
    results = SpeciesList.joins(:species_list_observations).
              group(:user_id).distinct.
              select(:user_id, Arel.star.count.as("cnt"))

    results.to_h do |record|
      [record.user_id, { species_list_entries: record.cnt }]
    end
  end

  # Exception for versions: Corrects for double-counting of versioned records.
  # NOTE: arel_table[:column].count(true) means "COUNT DISTINCT column"
  def self.refresh_versions(parent_table)
    # parent_class = parent_table.classify.constantize
    # version_class = "#{parent_class}::Version".constantize
    # parent_id = "#{parent_table}_id"

    # parent_class.joins(:versions).
    #   group(:user_id).distinct.
    #   select(
    #     :user_id,
    #     where.not(parent_class[:user_id].eq(version_class[:user_id])).
    #     count(true).as("cnt")
    #   )
  end

  # Regular counts keyed by user_id:
  def self.refresh_regular_field(table, field)
    field_class = table.to_s.classify.constantize

    results = field_class.group(:user_id).distinct.
              select(:user_id, Arel.star.count.as("cnt"))

    results.to_h do |record|
      [record.user_id, { "#{field}": record.cnt }]
    end
  end
end
