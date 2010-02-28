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
#  get_field_count::         Looks up total number of entries in a given table.
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
################################################################################

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
  #  FIELD_WEIGHTS::    Weight of each category, i.e. number of points for each record.
  #  FIELD_TABLES::     Table to query.
  #  FIELD_CONDITIONS:: Additional conditions.
  #
  #  The basic query for stats for the entire site is:
  #
  #    SELECT COUNT(*) FROM table
  #
  #  The basic query for stats for a single user is:
  #
  #    SELECT COUNT(*) FROM table WHERE user_id = 123
  #
  #  The only exception is species_list_entries, which does a simple join:
  #
  #    SELECT COUNT(*) FROM species_lists s, observations_species_lists os
  #      WHERE user_id = 123 AND s.id = os.species_list_id
  #
  ##############################################################################

  # List of the categories.
  ALL_FIELDS = [
    :name_descriptions_authors,
    :name_descriptions_editors,
    :images,
    :location_descriptions_authors,
    :location_descriptions_editors,
    :species_lists,
    :species_list_entries,
    :comments,
    :observations,
    :namings,
    :votes,
    :users
  ]

  # Relative score for each category.
  FIELD_WEIGHTS = {
    :name_descriptions_authors     => 100,
    :name_descriptions_editors     => 10,
    :images                        => 10,
    :location_descriptions_authors => 10,
    :location_descriptions_editors => 5,
    :species_lists                 => 5,
    :species_list_entries          => 1,
    :comments                      => 1,
    :observations                  => 1,
    :namings                       => 1,
    :votes                         => 1,
    :users                         => 0
  }

  # Table to query to get score for each category.  (Default is same as the
  # category name.)
  FIELD_TABLES = {
    :species_list_entries => "observations_species_lists",
  }

  # Additional conditions to use for each category.
  FIELD_CONDITIONS = {
    :users => "`verified` IS NOT NULL"
  }

################################################################################
#
# :section: Public Interface
#
################################################################################

  # This is called every time any object (not just one we care about) is
  # created or destroyed.  Figure out what kind of object from the class name,
  # and then update the owner's contribution as appropriate.
  def self.update_contribution(mode, obj, field=nil, user=nil, num=1)
    field ||= obj.class.to_s.tableize.to_sym
    weight = FIELD_WEIGHTS[field]
    if weight && weight > 0 &&
       obj.respond_to?('user_id') &&
       (user ||= obj.user)
      user.contribution ||= 0
      if mode == :create || mode == :add
        user.contribution += weight * num
      elsif mode == :destroy || mode == :remove
        user.contribution -= weight * num
      end
      user.save
# puts ">>>> #{mode} #{field} #{weight} #{num} (##{obj.id || 'x'}#{obj.respond_to?(:text_name) ? ' ' + obj.text_name : ''}) -> #{user.login}=#{user.contribution}"
# else puts ">>>> #{mode} #{field} (##{obj.id || 'x'}#{obj.respond_to?(:text_name) ? ' ' + obj.text_name : ''})"
# puts obj.args.inspect if obj.is_a?(Transaction)
    end
  end

  # Return stats for entire site.  Returns simple hash mapping category to
  # number of records of that category.
  #
  #   data = SiteData.new.get_site_data
  #   num_images = data[:images]
  #
  def get_site_data
    result = {}
    for field in ALL_FIELDS
      result[field] = get_field_count(field)
    end
    result
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

  # Load stats for all User's.  Returns nothing.  Use get_user_data to query
  # individual User's stats.  (This is probably prohibitively expensive.)
  #
  #   data = SiteData.new
  #   data.get_all_user_data
  #   for user in user_list
  #     hash = data.get_user_data(user.id)
  #   end
  #
  def get_all_user_data
    load_user_data(nil)
  end

################################################################################
#
# :section: Private Helpers
#
################################################################################

private

  # Calculate score for a set of results:
  #
  #   score = calc_metric(
  #     :images        => 10,
  #     :observations  => 10,
  #     :comments      => 23,
  #     :species_lists => 1,
  #     ...
  #   )
  #
  def calc_metric(fields) # :doc:
    metric = 0
    if fields
      for field in ALL_FIELDS
        metric += FIELD_WEIGHTS[field] * fields[field].to_i
      end
      metric += fields[:bonuses].to_i
      fields[:metric] = metric
    end
    return metric
  end

  # Do a query for the number of records in a given category for the entire
  # site.  This is not cached.  Most of these should be inexpensive queries.
  #
  #   count = get_field_count(:images)
  #   # SELECT COUNT(*) FROM `images`
  #
  #   count = get_field_count(:users)
  #   # SELECT COUNT(*) FROM `users` WHERE `verified` IS NOT NULL
  #
  def get_field_count(field) # :doc:
    table = FIELD_TABLES[field] || field.to_s
    query = "SELECT COUNT(*) FROM `#{table}`"
    if FIELD_CONDITIONS[field]
      query += " WHERE #{FIELD_CONDITIONS[field]}"
    end
    User.connection.select_value(query).to_i
  end

  # Do a query to get the number of records in a given category broken down
  # by User.  This is cached in @user_data.  Gets for a single User, or if
  # none passed in, gets stats for every User.
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
  #
  def load_field_counts(field, user_id=nil) # :doc:
    tables = FIELD_TABLES[field] || field.to_s
    conditions = user_id ? "user_id = #{user_id}" : "user_id > 0"

    # Some categories require extra joins and/or conditions.
    case field
      when :species_list_entries
        tables = "species_lists s, observations_species_lists os"
        conditions += " AND s.id=os.species_list_id"
    end

    query = %(
      SELECT COUNT(*) AS c, user_id AS u
      FROM #{tables}
      WHERE #{conditions}
      GROUP BY u
      ORDER BY c DESC
    )

    # Get data as:
    #   data = [
    #     {'u' => user_id, 'c' => count},
    #     {'u' => user_id, 'c' => count},
    #     ...
    #   ]
    data = User.connection.select_all(query)

    # Fill in @user_data structure.
    for d in data
      user_id = d['u'].to_i
      @user_data[user_id] ||= {}
      @user_data[user_id][field] = d['c'].to_i
    end
  end

  # Load all the stats for a given User.  (Load for all User's if none given.)
  #
  #   load_user_data(user.id)
  #   user.contribution = @user_data[user.id][:metric]
  #
  def load_user_data(id=nil) # :doc:
    if !id
      @user_id = nil
      users = User.find(:all)
    else
      @user_id = id.to_i
      users = [User.find(id)]
    end

    # Prime @user_data structure.
    @user_data = {}
    for user in users
      @user_data[user.id] = {
        :id      => user.id,
        :name    => user.unique_text_name,
        :bonuses => user.sum_bonuses,
      }
    end

    # Load record counts for each category.
    # (The :users category only applies to site-wide stats.)
    for field in ALL_FIELDS - [:users]
      load_field_counts(field)
    end

    # Now fix any user contribution caches that have the incorrect number.
    # (Add in user bonuses here, too.)
    for user in users
      contribution = calc_metric(@user_data[user.id])
      if user.contribution != contribution
        user.contribution = contribution
        user.save
      end
    end
  end
end
