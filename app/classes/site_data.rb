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

  # Return stats for entire site. Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_site_data
  #   num_images = data[:images]
  #
  def get_site_data
    SITE_WIDE_FIELDS.index_with { |field| field_count(field) }
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

end
