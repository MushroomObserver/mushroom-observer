#  Created by Nathan Wilson on 2007-05-12.
#  Copyright (c) 2007. All rights reserved.

class NameSorter
  attr_reader :new_name_strs, :single_name_strs, :single_names, :multiple_name_strs
  attr_accessor :chosen_names
  
  def all_name_strs
    @new_name_strs + @multiple_name_strs + @single_name_strs
  end
  
  def initialize
    # The first four are for managing the values entered into the Species field
    @new_name_strs = [] # List of strings
    @single_name_strs = [] # List of strings
    @single_names = [] # List of [Name, Time].  A Timestamp of nil implies now.
    @multiple_name_strs = [] # List of strings
  end
  
  def only_single_names
    (@new_name_strs == []) and (@multiple_name_strs == [])
  end
  
  def add_name(ns, timestamp=nil)
    name_str = ns.strip
    chosen = false
    if @chosen_names
      chosen_id = @chosen_names[name_str]
      if chosen_id
        @single_name_strs.push name_str
        @single_names.push [Name.find(chosen_id), timestamp]
        chosen = true
      end
    end
    if not chosen
      names = Name.find_names(name_str)
      len = names.length
      if len == 0
        @new_name_strs.push name_str
      elsif len == 1
        @single_name_strs.push name_str
        @single_names.push [names[0], nil]
      else
        @multiple_name_strs.push name_str
      end
    end
  end
  
  def sort_names(name_list)
    for n in name_list
      add_name(n)
    end
  end

end
