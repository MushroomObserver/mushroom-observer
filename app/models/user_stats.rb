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
#
#  == Counts of translation_strings_versions per language:
#
#  ar::
#  be::
#  de::
#  el::
#  es::
#  fa::
#  fr::
#  it::
#  jp::
#  pl::
#  pt::
#  ru::
#  tr::
#  uk::
#  zh::

class UserStats < AbstractModel
  belongs_to :user

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
    votes: { weight: 1 }
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
  def self.update_contribution(mode, obj, user_id = nil, num = 1)
    # Two modes:
    # 1) pass in object,
    # 2) pass in field name, when it's not ::model
    if obj.is_a?(ActiveRecord::Base)
      field = get_applicable_field(obj)
      user_id ||= obj&.user_id
    else
      field = obj
      user_id ||= User.current_id
    end
    # NOTE: this is a universal callback on save so `obj` could be anything,
    #       including records we don't count
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
    @user_data
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
      bonuses: user.sum_bonuses
    }
    add_language_contributions(user)

    # Refresh record counts for each category of @user_data.
    ALL_FIELDS.each_key { |field| refresh_field_count(field, id) }

    update(
      @user_data.except(
        :id, :name, :bonuses, :languages, :languages_itemized
      )
    )

    # Calculate full contribution for each user.
    # @metric_data = @user_data.except(:user_id)
    # @metric_data[:id] = @user_data[:user_id]
    contribution = calc_metric(@user_data)
    # Make sure contribution caches are correct.
    debugger
    return unless user.contribution != contribution

    user.contribution = contribution
    user.save
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

    table = if ALL_FIELDS.key?(field)
              (ALL_FIELDS[field][:table] || field).to_s
            else
              field.to_s
            end

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
    SpeciesList.joins(:species_list_observations).
      where(user_id: user_id).count
  end

  # Exception for versions: Corrects for double-counting of versioned records.
  # NOTE: the version classes need `.arel_table`, unlike other models
  def count_versions(parent_table, user_id)
    parent_class = parent_table.classify.constantize
    version_class = "#{parent_class}::Version".constantize
    parent_id = "#{parent_table}_id"

    parent_class.joins(:versions).
      where(user_id: user_id).
      where.not(
        parent_class[:user_id].eq(version_class.arel_table[:user_id])
      ).distinct.select(version_class.arel_table[:"#{parent_id}"]).count
  end

  # Regular count, by :user_id, or :id if table is `users`
  def count_regular_field(table, user_id)
    field_class = table.to_s.classify.constantize
    t_user_id = (table == "users" ? :id : :user_id)

    field_class.where("#{t_user_id}": user_id).count
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

  #  GROUPED BY USER ID BUT WITHOUT `sum`
  #
  # # Exception for species_list_entries, does a simple join:
  # def count_species_list_observations(user_id)
  #   SpeciesList.joins(:species_list_observations).
  #     where(user_id: user_id).group(:user_id).
  #     select(Arel.star.count.as("cnt"), :user_id).order(cnt: :desc)
  # end

  # # Exception for versions: Corrects for double-counting of versioned records.
  # # NOTE: arel_table[:column].count(true) means "COUNT DISTINCT column"
  # def count_versions(parent_table, user_id)
  #   parent_class = parent_table.classify.constantize
  #   version_class = "#{parent_class}::Version".constantize
  #   parent_id = "#{parent_table}_id"

  #   parent_class.joins(:versions).
  #     where(user_id: user_id).
  #     where.not(parent_class[:user_id].eq(version_class[:user_id])).
  #     group(:user_id).
  #     select(version_class[:"#{parent_id}"].count(true).as("cnt"), :user_id).
  #     order(cnt: :desc)
  # end

  # # Regular count, by :user_id, or :id if table is `users`
  # def count_regular_field(table, user_id)
  #   field_class = table.to_s.classify.constantize
  #   t_user_id = (table == "users" ? :id : :user_id)

  #   field_class.where("#{t_user_id}": user_id).group(:"#{t_user_id}").
  #     select(Arel.star.count.as("cnt"), :"#{t_user_id}").order(cnt: :desc)
  # end
end