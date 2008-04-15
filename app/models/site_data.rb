#  Created by Nathan Wilson on 2007-05-12.
#  Copyright (c) 2007. All rights reserved.

# This file manages user rankings.
#
# Global Constants:
#   ALL_FIELDS                List of fields presumably in pleasing order.
#   FIELD_WEIGHTS             Weight of each field in user metric.
#   FIELD_TITLES              Title to use for each field in view.
#   FIELD_TABLES              Name of table to count rows of for each field.
#                             (only the exceptions; default is table name is
#                             same as field name)
#
# Public:
#   get_site_data             Returns stats for entire site.
#   get_user_data(user_id)    Returns stats for given user.
#   get_all_user_data         Returns stats for all users.
#
#   SiteData.update_contribution(mode, obj)     Keep user.contribution
#   SiteData.create_species_list_entries(spl)    cache up to date.
#   SiteData.destroy_species_list_entries(spl)
#
# Private:
#   calc_metric(fields)       Calculates score of a single user.
#   get_field_count(field)    Looks up number of entries in a given table.
#   load_user_data(id=nil)    Populates @user_data (some stuff hard-coded).
#   load_field_counts(field, query=nil)
#                             Populates a single column in @user_data.
#
# Static internal data structure: (created by load_user_data)
#   @user_data        This is a 2-D hash keyed on user_id then field name:
#     :images           Number of images the user has posted.
#     ...
#     :observations     Number of observations user has posted.
#     :name             User's legal_name.
#     :id               User's id.

ALL_FIELDS = [
  :images,
  :names,
  :past_names,
  :locations,
  :past_locations,
  :species_lists,
  :species_list_entries,
  :comments,
  :observations,
  :namings,
  :votes,
  :users
]

FIELD_WEIGHTS = {
  :images => 10,
  :names => 10,
  :past_names => 10,
  :locations => 5,
  :past_locations => 5,
  :species_lists => 5,
  :species_list_entries => 1,
  :comments => 1,
  :observations => 1,
  :namings => 1,
  :votes => 1,
  :users => 0
}

FIELD_TITLES = {
  :images => "Images",
  :names => "New Names",
  :past_names => "Name Changes",
  :locations => "New Locations",
  :past_locations => "Location Changes",
  :species_lists => "Species Lists",
  :species_list_entries => "Species List Entries",
  :comments => "Comments",
  :observations => "Observations",
  :namings => "Proposed IDs",
  :votes => "Votes",
  :users => "Members"
}

# Default is field.to_s.  This is the table it queries to get the number of objects.
FIELD_TABLES = {
  :species_list_entries => "observations_species_lists",
}

class SiteData

  # This is called every time any object (not just ones we care about) is
  # created or destroyed.  Figure out what kind of object from the class name,
  # and then update the owner's contribution as appropriate.
  def self.update_contribution(mode, obj, field=nil, num=1)
    field = obj.class.to_s.tableize.to_sym if !field
    weight = FIELD_WEIGHTS[field]
    if weight && weight > 0 &&
       obj.respond_to?("user") && (user = obj.user)
      user.contribution = 0 if !user.contribution
      user.contribution += (mode == :create ? weight : -weight) * num
# print ">>>>>>>>>>>>>>> #{user.login} #{mode} #{field} #{num}\n"
      user.save
    end
  end

  def get_site_data
    result = {}
    for field in ALL_FIELDS
      result[field] = get_field_count(field)
    end
    result
  end

  def get_user_data(id)
    load_user_data(id)
    @user_data[@user_id]
  end

  def get_all_user_data
    load_user_data(nil)
  end

private
  def calc_metric(fields)
    metric = 0
    if fields
      for field in ALL_FIELDS
        count = fields[field] || 0
        metric += FIELD_WEIGHTS[field] * count
      end
    end
    fields[:metric] = metric
    return metric
  end

  def get_field_count(field)
   result = 0
   table = FIELD_TABLES[field]
   if table.nil?
     table = field
   end
   query = "select count(*) as c from %s" % table
   data = User.connection.select_all(query)
   for d in data
     result = d['c'].to_i
   end
   result
  end

  def load_user_data(id=nil)
    @user_id = id
    users = nil
    if id.nil?
      users = User.find(:all)
    else
      @user_id = id.to_i
      users = [User.find(id)]
    end

    # Fill in table by performing one query for each object being counted.
    @user_data = {}
    for user in users
      @user_data[user.id] = { :name => user.legal_name, :id => user.id }
    end
    for field in ALL_FIELDS
      table = FIELD_TABLES[field]
      if !table
        load_field_counts(field) if field != :users
      else
        # This exception only occurs for species list entries for the moment.
        query = ""
        if @user_id
          query = %(
            SELECT count(*) as c, user_id
            FROM species_lists s, observations_species_lists os
            WHERE s.id=os.species_list_id and user_id = #{@user_id}
            GROUP BY user_id
            ORDER BY c desc
          )
        else
          query = %(
            SELECT count(*) as c, user_id
            FROM species_lists s, observations_species_lists os
            WHERE s.id=os.species_list_id and user_id > 0
            GROUP BY user_id
            ORDER BY c desc
          )
        end
        load_field_counts(:species_list_entries, query)
      end
    end

    # Now fix any user contribution caches that have the incorrect number.
    for user in users
      contribution = calc_metric(@user_data[user.id])
      if user.contribution != contribution
        user.contribution = contribution
        user.save
      end
    end
  end

  def load_field_counts(field, query=nil)
    result = []
    conditions = ""
    if @user_id
      conditions = "user_id = %s" % @user_id
    else
      conditions = "user_id > 0"
    end
    if query.nil?
      query = "select count(*) as c, user_id from %s where %s group by user_id" % [field, conditions]
    end
    data = User.connection.select_all(query)
    for d in data
      user_id = d['user_id'].to_i
      @user_data[user_id][field] = d['c'].to_i
    end
  end
end
