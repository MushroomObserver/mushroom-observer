# frozen_string_literal: true

# Keep track of each user's contributions

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
    table = obj.class.to_s.tableize.to_sym

    ALL_FIELDS.select { |_f, e| e[:table] == table }.keys.first || table
  end

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
