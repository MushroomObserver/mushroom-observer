#  Created by Nathan Wilson on 2007-05-12.
#  Copyright (c) 2007. All rights reserved.
require 'name_parse'

class NameSorter
  attr_reader :all_names
  attr_accessor :approved_deprecated_names
  attr_accessor :approved_synonym_ids
  attr_accessor :chosen_names
  attr_accessor :chosen_approved_names
  attr_reader :deprecated_name_strs
  attr_reader :has_new_synonyms
  attr_reader :has_unapproved_deprecated_names
  attr_reader :multiple_line_strs
  attr_reader :new_line_strs # Each line containing a new name
  attr_reader :new_name_strs # Each new name
  attr_reader :single_line_strs
  attr_reader :single_names
  attr_reader :synonym_data
  
  def all_line_strs
    @new_line_strs + @multiple_line_strs + @single_line_strs
  end
  
  def initialize
    @all_names = [] # List of Names
    @approved_deprecated_names = [] # List of strings
    @approved_synonym_ids = [] # List of name_ids
    @chosen_names = {} # name_str -> name_id
    @chosen_approved_names = {} # name_str -> name_id
    @deprecated_name_strs = [] # List of strings
    @has_new_synonyms = false
    @has_unapproved_deprecated_names = false
    @multiple_line_strs = [] # List of strings
    @new_line_strs = [] # List of strings
    @new_name_strs = [] # List of strings
    @single_line_strs = [] # List of strings
    @single_names = [] # List of [Name, Time].  A Timestamp of nil implies now.
    @synonym_data = [] # List of [NameParse, [Name...]]
  end
  
  def reset_new_names
    @new_name_strs = []
    @new_line_strs = []
  end
  
  def only_single_names
    (@new_name_strs == []) and (@multiple_line_strs == [])
  end
  
  def push_synonym_id(id)
    if id.class == Fixnum
      @approved_synonym_ids.push(id)
    else
      raise TypeError.new("NameSorter synonym ids must be Fixnums not %s" % id.class)
    end
  end
  
  def append_approved_synonyms(synonyms)
    if synonyms # Allow for nil
      if synonyms.class == String
        synonyms = synonyms.split("/")
      end
      if synonyms.class == Array
        synonyms.each {|id| push_synonym_id(id.to_i)}
      else
        raise TypeError.new("Only Arrays can be appended to a NameSorter synonym list not %s" % synonyms.class)
      end
    end
  end
  
  def add_chosen_names(new_names)
    if new_names
      @chosen_names.merge!(new_names)
    end
  end

  def add_approved_deprecated_names(new_names)
    if new_names
      for n in new_names
        @approved_deprecated_names += n.split("/")
      end
    end
  end
  
  def check_for_deprecated_name(name, name_str=nil)
    if name.deprecated
      str = name_str || name.search_name
      @deprecated_name_strs.push(str)
      if @approved_deprecated_names.nil? or !@approved_deprecated_names.member?(str)
        @has_unapproved_deprecated_names = true
      end
    end
  end
      
  def check_for_deprecated_names(names, name_str=nil)
    for n in names
      check_for_deprecated_name(n, name_str)
    end
  end

  def check_for_deprecated_checklist(checklist)
    if checklist
      for key, value in checklist
        if value == 'checked'
          check_for_deprecated_name(Name.find(key.to_i))
        end
      end
    end
  end
  
  def add_name(spl_line, timestamp=nil)
    # Need to store all this data
    name_parse = NameParse.new(spl_line)
    line_str = name_parse.line_str
    name_str = name_parse.name
    chosen = false

    # Need all deprecated names even when another name is chosen
    # in case something else forces a redisplay
    names = name_parse.find_names()
    check_for_deprecated_names(names, name_str)
    
    if @chosen_names
      chosen_id = @chosen_names[name_str]
      if chosen_id
        @single_line_strs.push(line_str) # (name_str)
        chosen_name = Name.find(chosen_id)
        names = [chosen_name]
        @single_names.push([chosen_name, timestamp])
        @all_names.push(chosen_name)
        chosen = true
      end
    end
    if not chosen
      @all_names += names
      len = names.length
      if len == 0
        @new_line_strs.push(line_str) # (name_str)
        @new_name_strs.push(name_parse.search_name)
      elsif len == 1
        @single_line_strs.push(line_str) # (name_str)
        @single_names.push([names[0], nil])
      else
        @multiple_line_strs.push(line_str) # (name_str)
      end
    end
    
    if name_parse.has_synonym()
      @has_new_synonyms = true
      if name_parse.find_synonym_names.length == 0
        @new_name_strs.push(name_parse.synonym_search_name)
      end
      @synonym_data.push([name_parse, names]) # Keep names in addition to parse for the chosen filter
    end
  end
  
  def create_new_synonyms
    for parse, names in @synonym_data
      if names.length == 1
        name = Name.find(names[0].id)
        synonym_names = parse.find_synonym_names
        for s in synonym_names
          s.deprecated = true
          s.save
          name.merge_synonyms(s)
        end
      else
        raise TypeError.new("Unexpected ambiguity: #{names.map{|n| n.search_name}.join(', ')}")
      end
    end
  end

  def synonym_name_strs
    result = []
    for name in @all_names
      synonym = name.synonym
      if synonym
        for s in synonym.names
          result.push(s.display_name)
        end
      end
    end
    result
  end

  def proposed_synonym_ids
    result = []
    result += @approved_synonym_ids
    for name in @all_names
      synonym = name.synonym
      if synonym
        for s in synonym.names
          result.push(s.id)
        end
      else
        result.push(name.id)
      end
    end
    result.uniq
  end
  
  def only_approved_synonyms
    result = true
    ok_name_ids = @approved_synonym_ids + @all_names.map {|n| n.id }
    # error_string = "ok_nameids: [%s]\n" % ok_name_ids.join(', ') +
    # "proposed_synonym_ids: [%s]\n" % self.proposed_synonym_ids.join(', ')
    for proposed_id in self.proposed_synonym_ids
      # error_string += "%s\n" % proposed_id
      if not ok_name_ids.member?(proposed_id)
        # raise TypeError.new("member? failed")
        result = false
        break
      end
    end
    # raise TypeError.new(error_string)
    result
  end
  
  def sort_names(name_list)
    for n in name_list
      add_name(n)
    end
  end
end
