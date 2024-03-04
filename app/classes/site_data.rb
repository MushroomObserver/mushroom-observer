# frozen_string_literal: true

#
#  = Site Data
#
#  This class manages user contributions / rankings.
#
#  == Instance Methods
#  ==== Public
#  get_site_data::           Returns stats for entire site.
#  ==== Private
#  field_count::             Looks up total number of entries in a given table.
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
end
