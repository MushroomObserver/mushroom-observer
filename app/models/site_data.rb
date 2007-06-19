#  Created by Nathan Wilson on 2007-05-12.
#  Copyright (c) 2007. All rights reserved.

ALL_FIELDS = [:images, :names, :past_names, :species_lists, :species_list_entries, :comments, :observations]

FIELD_WEIGHTS = {
  :images => 10,
  :names => 10,
  :past_names => 10,
  :species_lists => 5,
  :species_list_entries => 1,
  :comments => 1,
  :observations => 1
}

FIELD_TITLES = {
  :images => "Images",
  :names => "Names",
  :past_names => "Previous Name Edits",
  :species_lists => "Species Lists",
  :species_list_entries => "Species List Entries",
  :comments => "Comments",
  :observations => "Observations"
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
      metric = 0
      for field in ALL_FIELDS
        count = v[field] || 0
        metric += FIELD_WEIGHTS[field] * count
      end
      user_ranking.push([metric, v[:id], v[:name]])
    end
    user_ranking.sort.reverse
  end
 
private
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
      conditions = "user_id = %s" % @user_id # Worry about SQL injection?
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
