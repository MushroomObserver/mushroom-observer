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
#   get_user_ranking          Returns list of users sorted by ranking.
#   get_user_metric(id)       Returns "score" of a given user.
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
  :users => 0
}

FIELD_TITLES = {
  :images => "Images",
  :names => "Names",
  :past_names => "Previous Name Edits",
  :locations => "Locations",
  :past_locations => "Previous Location Edits",
  :species_lists => "Species Lists",
  :species_list_entries => "Species List Entries",
  :comments => "Comments",
  :observations => "Observations",
  :users => "Members"
}

# Default is field.to_s
FIELD_TABLES = {
  :species_list_entries => "observations_species_lists",
}

class SiteData
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

  def get_user_ranking
    load_user_data
    user_ranking = []
    for k, v in @user_data
      metric = calc_metric(v)
      user_ranking.push([metric, v[:id], v[:name]])
    end
    user_ranking.sort.reverse
  end

  def get_user_metric(id)
    load_user_data(id)
    calc_metric(@user_data[id])
  end

private
  def calc_metric(fields)
    metric = 0
    for field in ALL_FIELDS
      count = fields[field] || 0
      metric += FIELD_WEIGHTS[field] * count
    end
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
    @user_data = {}
    for user in users
      @user_data[user.id] = { :name => user.legal_name, :id => user.id }
    end
    load_field_counts(:images) # 20
    load_field_counts(:names) # 10
    load_field_counts(:past_names) # 10
    load_field_counts(:locations) # 5
    load_field_counts(:past_locations) # 5
    load_field_counts(:species_lists) # 5
    load_field_counts(:comments) # 1
    load_field_counts(:observations) # 1
    query = ""
    if @user_id
      query = "select count(*) as c, user_id from species_lists, observations_species_lists " +
        "where species_lists.id=observations_species_lists.species_list_id and user_id = %s " % @user_id +
        "group by user_id order by c desc"
    else
      query = "select count(*) as c, user_id from species_lists, observations_species_lists " +
        "where species_lists.id=observations_species_lists.species_list_id and user_id > 0 group by user_id order by c desc"
    end
    load_field_counts(:species_list_entries, query) # 1
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
