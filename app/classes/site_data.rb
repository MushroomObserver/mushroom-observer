# frozen_string_literal: true

#
#  = Site Data
#
#  This class manages user contributions / rankings.
#
#  == Class Methods
#
#  update_contribution::    Callback that keeps User contribution up to date.
#
#  == Instance Methods
#  ==== Public
#  get_site_data::           Returns stats for entire site.
#  get_user_data::           Returns stats for given user.
#  get_all_user_data::       Returns stats for all users.
#  ==== Private
#  load_user_data::          Populates @user_data.
#  load_field_counts::       Populates a single column in @user_data.
#  calc_metric::             Calculates contribution score of a single user.
#  field_count::             Looks up total number of entries in a given table.
#
#  == Internal Data Structure
#
#  The private method load_user_data caches its information in the instance
#  variable +@user_data+.  Its structure is as follows:
#
#    @user_data = {
#      user.id => {
#        :id         => user.id,
#        :name       => user.unique_text_name,
#        :bonuses    => user.sum_bonuses,
#        :<category> => <num_records_in_category>,
#        :metric     => <weighted_sum_of_category_counts>,
#      },
#    }
#
class SiteData
  ##############################################################################
  #
  #  :section: Category Definitions
  #
  #  User's contributions are the weighted sum of the number of records in
  #  several categories, such as Observation's posted, Image's uploaded, Name's
  #  authored, etc.  These categories are described by a set of constants:
  #
  #  ALL_FIELDS::       List of category names, in order.
  #    :weight::        Weight of each category: number of points per record.
  #    :table::         Table to query.
  #
  #  The default query for stats for the entire site is:
  #
  #    SELECT COUNT(*) FROM table
  #
  #  The default query for stats for a single user is:
  #
  #    SELECT COUNT(*) FROM table WHERE user_id = 123
  #
  #  The only exception is species_list_entries, which does a simple join:
  #
  #    SELECT COUNT(*) FROM species_lists s, species_list_observations os
  #      WHERE user_id = 123 AND s.id = os.species_list_id
  #
  ##############################################################################

  # List of the categories.  This might be the order they appear in show_user.
  #   weight: Relative score for each category.
  #   table: name of table to query, if it's not the same name as the key
  #
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
    listed_taxa: { weight: 0 },
    observed_taxa: { weight: 0 },
    sequences: { weight: 0 },
    namings: { weight: 1 },
    comments: { weight: 1 },
    votes: { weight: 1 },
    users: { weight: 0 },
    contributing_users: { weight: 0, table: :users }
  }.freeze

  SITE_WIDE_ONLY_FIELDS = [
    :listed_taxa,
    :observed_taxa,
    :users,
    :contributing_users
  ].freeze

  SITE_WIDE_FIELDS = [
    :images,
    :observations,
    :sequences,
    :sequenced_observations,
    :listed_taxa,
    :observed_taxa,
    :name_description_authors,
    :locations,
    :location_description_authors,
    :species_lists,
    :species_list_entries,
    :namings,
    :comments,
    :votes,
    :contributing_users
  ].freeze

  # -----------------------------
  #  :section: Public Interface
  # -----------------------------

  # Fields that should appear on a user page
  def self.user_fields
    ALL_FIELDS.except(*SITE_WIDE_ONLY_FIELDS)
  end

  def self.fields_with_weight
    ALL_FIELDS.select { |_f, e| e[:weight].positive? }
  end

  def self.user_fields_with_weight
    user_fields.select { |_f, e| e[:weight].positive? }
  end

  # This is called every time any object (not just one we care about) is
  # created or destroyed.  Figure out what kind of object from the class name,
  # and then update the owner's contribution as appropriate.
  # NOTE: This is only approximate.  There are now nontrivial calculations,
  # such as awarding extra points for observations with vouchers, which won't
  # be done right until someone looks at that user's summary page.
  def self.update_contribution(mode, obj, user_id = nil, num = 1)
    # Two modes: 1) pass in object, 2) pass in field name, when it's not ::model
    if obj.is_a?(ActiveRecord::Base)
      field = get_applicable_field(obj)
      user_id ||= obj&.user_id
    else
      field = obj
      user_id ||= User.current_id
    end
    # NOTE: this is a universal callback on save
    # so the obj could be anything, including records we don't count
    weight = ALL_FIELDS.key?(field) ? ALL_FIELDS[field.to_sym][:weight] : 0
    return unless weight&.positive? && user_id&.positive?

    update_weight(calc_impact(weight * num, mode), user_id)
    UserStats.where(id: user_id).increment!(field, by: num)
  end

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

  def self.update_weight(impact, user_id)
    return if impact.zero?

    User.find(user_id).increment!(:contribution, impact)
  end

  # An applicable field is a field that affects contribution
  def self.get_applicable_field(obj)
    table = obj.class.to_s.tableize
    field = table.to_sym

    ALL_FIELDS.key?(field) ? (ALL_FIELDS[field][:table] || field) : field
  end

  # Return stats for entire site. Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_site_data
  #   num_images = data[:images]
  #
  def get_site_data
    ALL_FIELDS.keys.index_with { |field| field_count(field) }
  end

  # ----------------------------
  #  :section: Private Helpers
  # ----------------------------

  private

  # Do a query for the number of records in a given category for the entire
  # site. This is not cached. Most of these should be inexpensive queries.
  def field_count(field)
    return 0 if /^(\w+)_versions/.match?(field.to_s)

    case field.to_sym
    when :species_list_entries
      SpeciesListObservation.count
    when :sequenced_observations
      Sequence.select(:observation_id).distinct.count
    when :listed_taxa
      Name.count
    when :observed_taxa
      Observation.select(:name_id).distinct.count
    when :contributing_users
      User.where(contribution: 1..).count
    when :users
      User.where.not(verified: nil).count
    else
      field.to_s.classify.constantize.count
    end
  end

  # Do a query to get the number of records in a given category broken down
  # by User.  This is cached in @user_data.  Gets for a single User.
  #
  #   # Get number of images for current user.
  #   load_field_counts(:images, User.current.id)
  #   num_images = @user_data[:images]
  #
  def load_field_counts(field, user_id = nil)
    return unless user_id

    table = FIELD_TABLES[field] || field.to_s

    data = case table
           when "species_list_observations"
             count_species_list_observations(user_id)
           when /^(\w+)_versions/
             parent_table = $LAST_MATCH_INFO[1]
             count_versions(parent_table, user_id)
           else
             count_regular_field(table, user_id)
           end

    data.each_key do |cnt|
      @user_data ||= {}
      @user_data[field] = cnt.to_i
    end
  end

  # Exception for species_list_entries, does a simple join:
  def count_species_list_observations(user_id)
    SpeciesList.joins(:species_list_observations).
      where(user_id: user_id).group(:user_id).
      select(Arel.star.count.as("cnt"), :user_id).order(cnt: :desc)
  end

  # Exception for versions: Corrects for double-counting of versioned records.
  # NOTE: arel_table[:column].count(true) means "COUNT DISTINCT column"
  def count_versions(parent_table, user_id)
    parent_class = parent_table.classify.constantize
    version_class = "#{parent_class}::Version".constantize
    parent_id = "#{parent_table}_id"

    parent_class.joins(:versions).
      where(user_id: user_id).
      where.not(parent_class[:user_id].eq(version_class[:user_id])).
      group(:user_id).
      select(version_class[:"#{parent_id}"].count(true).as("cnt"), :user_id).
      order(cnt: :desc)
  end

  # Regular count, by :user_id, or :id if table is `users`
  def count_regular_field(table, user_id)
    field_class = table.to_s.classify.constantize
    t_user_id = (table == "users" ? :id : :user_id)

    field_class.where("#{t_user_id}": user_id).group(:"#{t_user_id}").
      select(Arel.star.count.as("cnt"), :"#{t_user_id}").order(cnt: :desc)
  end

  public

  #############################################################################

  # Return stats for a single User.  Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_user_data(user_id)
  #   num_images = data[:images]
  #
  def get_user_data(id)
    load_user_data(id)
    @user_data
  end

  private

  # Load all the stats for a given User.  (Load for all User's if none given.)
  #
  #   load_user_data(user.id)
  #   user.contribution = @user_data[:metric]
  #
  def load_user_data(id = nil)
    return unless id

    @user_id = id.to_i
    user = User.find(id)

    # Prime @user_data structure.
    @user_data ||= {}
    @user_data = {
      id: user.id,
      name: user.unique_text_name,
      bonuses: user.sum_bonuses
    }
    add_language_contributions(user)

    # Load record counts for each category of individual user data.
    SiteData.user_fields.each_key { |field| load_field_counts(field) }

    # Calculate full contribution for each user.
    contribution = calc_metric(@user_data)
    # Make sure contribution caches are correct.
    return unless user.contribution != contribution

    user.contribution = contribution
    user.save
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
    metric += data[:languages].to_i
    metric += data[:bonuses].to_i
    data[:metric] = metric
    metric
  end

  def add_language_contributions(user)
    language_contributions = Language.all.map do |lang|
      score = lang.official ? 0 : lang.calculate_users_contribution(user).to_i
      [lang, score]
    end
    @user_data[:languages] =
      language_contributions.sum { |_lang, score| score }
    @user_data[:languages_itemized] =
      language_contributions.select { |_lang, score| score.positive? }
  end
end
