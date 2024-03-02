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
# rubocop:disable Metrics/ClassLength
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
  #  FIELD_WEIGHTS::    Weight of each category: number of points per record.
  #  FIELD_TABLES::     Table to query.
  #  FIELD_CONDITIONS:: Additional conditions.
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
  ALL_FIELDS = [
    :name_description_authors,
    :name_description_editors,
    :names,
    :names_versions,
    :location_description_authors,
    :location_description_editors,
    :locations,
    :locations_versions,
    :images,
    :species_lists,
    :species_list_entries,
    :observations,
    :sequenced_observations,
    :sequences,
    :comments,
    :namings,
    :votes,
    :users,
    :contributing_users
  ].freeze

  SITE_WIDE_FIELDS = [:users, :contributing_users].freeze

  # Relative score for each category.
  FIELD_WEIGHTS = {
    comments: 1,
    contributing_users: 0,
    images: 10,
    location_description_authors: 50,
    location_description_editors: 5,
    locations: 10,
    locations_versions: 5,
    name_description_authors: 100,
    name_description_editors: 10,
    names: 10,
    names_versions: 10,
    namings: 1,
    observations: 1,
    sequences: 0,
    sequenced_observations: 0,
    species_list_entries: 1,
    species_lists: 5,
    users: 0,
    votes: 1
  }.freeze

  # Table to query to get score for each category.  (Default is same as the
  # category name.)
  FIELD_TABLES = {
    sequenced_observations: "sequences",
    species_list_entries: "species_list_observations",
    contributing_users: "users"
  }.freeze

  # Additional conditions to use for each category.
  FIELD_CONDITIONS = {
    users: "`verified` IS NOT NULL",
    contributing_users: "contribution > 0"
  }.freeze

  # Non-default unified queries for stats for the entire site
  FIELD_QUERIES = {
    contributing_users: User.where(contribution: 1..),
    sequenced_observations: Sequence.select(:observation_id).distinct,
    species_list_entries: SpeciesListObservation,
    users: User.where.not(verified: nil)
  }.freeze

  # Call these procs to determine if a given object qualifies for a given field.
  # FIELD_STATE_PROCS = {
  #   observations_with_voucher: lambda do |obs|
  #     obs.specimen && obs.notes.to_s.length >= 10 &&
  #       obs.thumb_image_id.to_i.positive?
  #   end,
  #   observations_without_voucher: lambda do |obs|
  #     !(obs.specimen && obs.notes.to_s.length >= 10 &&
  #       obs.thumb_image_id.to_i.positive?)
  #   end
  # }.freeze

  # -----------------------------
  #  :section: Public Interface
  # -----------------------------

  # This is called every time any object (not just one we care about) is
  # created or destroyed.  Figure out what kind of object from the class name,
  # and then update the owner's contribution as appropriate. NOTE: This is only
  # approximate.  There are now nontrivial calculations, such as awarding extra
  # points for observations with vouchers, which won't be done right until
  # someone looks at that user's summary page.
  def self.update_contribution(mode, obj, user_id = nil, num = 1)
    # Two modes: 1) pass in object, 2) pass in field name
    if obj.is_a?(ActiveRecord::Base)
      field = get_applicable_field(obj)
      user_id ||= begin
                    obj.user_id
                  rescue StandardError
                    nil
                  end
    else
      field = obj
      user_id ||= User.current_id
    end
    weight = FIELD_WEIGHTS[field]
    return unless weight&.positive? && user_id&.positive?

    update_weight(calc_impact(weight * num, mode), user_id)
  end

  def self.calc_impact(weight, mode)
    case mode
    when :del
      -weight
    when :chg
      0 # get_weight_change(obj, field)
    else
      weight
    end
  end

  def self.update_weight(impact, user_id)
    return if impact.zero?

    User.connection.update(%(
      UPDATE users SET contribution =
        IF(contribution IS NULL, #{impact}, contribution + #{impact})
      WHERE id = #{user_id}
    ))
  end

  def self.get_applicable_field(obj)
    table = obj.class.to_s.tableize
    field = table.to_sym
    # no field weight: contributing_users, seq, seq_obs
    unless FIELD_WEIGHTS[field]
      field = nil
      FIELD_TABLES.each do |field2, table2|
        next unless table2 == table

        # proc = FIELD_STATE_PROCS[field2]
        # next unless proc&.call(obj)

        field = field2
        break
      end
    end
    field
  end

  # This makes no sense without field procs!
  # def self.get_weight_change(obj, new_field)
  #   old_field = new_field
  #   FIELD_WEIGHTS[new_field] - FIELD_WEIGHTS[old_field]
  # end

  # Return stats for entire site. Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_site_data
  #   num_images = data[:images]
  #
  def get_site_data
    ALL_FIELDS.index_with do |field|
      field_count(field)
    end
  end

  # Return stats for a single User.  Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_user_data(user_id)
  #   num_images = data[:images]
  #
  def get_user_data(id)
    load_user_data(id)
    @user_data[@user_id]
  end

  # ----------------------------
  #  :section: Private Helpers
  # ----------------------------

  private

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

    ALL_FIELDS.each do |field|
      next unless data[field]

      # This fixes the double-counting of created records.
      if field.to_s =~ /^(\w+)_versions$/
        data[field] -= data[Regexp.last_match(1)] || 0
      end
      metric += FIELD_WEIGHTS[field] * data[field]
    end
    metric += data[:languages].to_i
    metric += data[:bonuses].to_i
    data[:metric] = metric
    metric
  end

  # Do a query for the number of records in a given category for the entire
  # site. This is not cached. Most of these should be inexpensive queries.
  def field_count(field)
    return 0 if /^(\w+)s_versions/.match?(field.to_s)

    # constantize is safe here because `field` is not user input
    FIELD_QUERIES[field]&.count || field.to_s.classify.constantize.count
  end

  # Do a query to get the number of records in a given category broken down
  # by User.  This is cached in @user_data.  Gets for a single User,
  #
  #   # Get number of images for current user.
  #   load_field_counts(:images, User.current.id)
  #   num_images = @user_data[User.current.id][:images]
  #
  #   # Get number of images for all users.
  #   load_field_counts(:images)
  #   for user_id User.all.map(&;id)
  #     num_images = @user_data[user_id][:images]
  #   end
  # rubocop:disable Metrics/MethodLength
  def load_field_counts(field, user_id = nil)
    return unless user_id

    count  = "*"
    table  = FIELD_TABLES[field] || field.to_s
    tables = "#{table} t"
    t_user_id = (table == "users" ? "t.id " : "t.user_id ")
    conditions = t_user_id + "= #{user_id}"

    # Exception for species list entries.
    if field == :species_list_entries
      tables = "species_lists t, #{table} os"
      conditions += " AND os.species_list_id = t.id"
    end

    # Exception for past versions.
    if table =~ /^(\w+)s_versions/
      parent = Regexp.last_match(1)
      count = "DISTINCT #{parent}_id"
      tables += ", #{parent}s p"
      conditions += " AND t.#{parent}_id = p.id"
      conditions += " AND #{t_user_id} != p.user_id"
    end

    if (extra_conditions = FIELD_CONDITIONS[field])
      conditions += " AND (#{extra_conditions})"
    end

    query = %(
      SELECT COUNT(#{count}) AS cnt, #{t_user_id}
      FROM #{tables}
      WHERE #{conditions}
      GROUP BY #{t_user_id}
      ORDER BY cnt DESC
    )

    # Get data as:
    #   data = [
    #     [count, user_id],
    #     [count, user_id],
    #     ...
    #   ]
    data = User.connection.select_rows(query)

    # Fill in @user_data structure.
    data.each do |cnt, usr_id|
      @user_data[usr_id.to_i] ||= {}
      @user_data[usr_id.to_i][field] = cnt.to_i
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Load all the stats for a given User.  (Load for all User's if none given.)
  #
  #   load_user_data(user.id)
  #   user.contribution = @user_data[user.id][:metric]
  #
  def load_user_data(id = nil)
    if id
      @user_id = id.to_i
      users = [User.find(id)]
    else
      @user_id = nil
      users = User.all
    end

    # Prime @user_data structure.
    @user_data = {}
    users.each do |user|
      @user_data[user.id] = {
        id: user.id,
        name: user.unique_text_name,
        bonuses: user.sum_bonuses
      }
      add_language_contributions(user)
    end

    # Load record counts for each category of individual user data.
    (ALL_FIELDS - SITE_WIDE_FIELDS).each { |field| load_field_counts(field) }

    # Calculate full contribution for each user.  This will also correct some
    # double-counting of versioned records.
    users.each do |user|
      contribution = calc_metric(@user_data[user.id])
      # Make sure contribution caches are correct.
      if user.contribution != contribution
        user.contribution = contribution
        user.save
      end
    end
  end

  def add_language_contributions(user)
    language_contributions = Language.all.map do |lang|
      score = lang.official ? 0 : lang.calculate_users_contribution(user).to_i
      [lang, score]
    end
    @user_data[user.id][:languages] =
      language_contributions.sum { |_lang, score| score }
    @user_data[user.id][:languages_itemized] =
      language_contributions.select { |_lang, score| score.positive? }
  end
end
# rubocop:enable Metrics/ClassLength
