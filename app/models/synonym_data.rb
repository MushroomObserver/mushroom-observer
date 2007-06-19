#  Created by Nathan Wilson on 2007-06-08.
#  Copyright (c) 2007. All rights reserved.

class NameParse
  attr_reader :name_rank
  attr_reader :name_str
  attr_reader :synonym_rank
  attr_reader :synonym_str
  
  # spl_line can be either:
  # <single_name>
  # <single_name> = <single_name>
  # where <single_name> is either
  # <search_name>
  # <rank> <search_name>
  def initialize(spl_line)
    result = []
    name_str = ''
    equal_pos = spl_line.index('=')
    if equal_pos
      name_str = spl_line[0..equal_pos-1].strip
      (@synonym_rank, @synonym_str) = parse_rank(spl_line[equal_pos+1..-1].strip)
    else
      name_str = spl_line.strip
      @synonym_rank = nil
      @synonym_str = nil
    end
    (@name_rank, @name_str) = parse_rank(name_str) + result
  end

  def has_synonym()
    @synonym_str != nil
  end
  
  def find_names()
    Name.find_names(@name_str, @name_rank)
  end
  
  def find_synonyms()
    result = []
    if @synonym_str
      result = Name.find_names(@synonym_str, @synonym_rank)
    end
    result
  end
  
  def parse_rank(str)
    space_pos = str.index(' ')
    if space_pos > 0
      rank = str[0..space_pos-1].to_sym
      if Name.all_ranks.member?(rank)
        name = str[space_pos..-1].strip
      else
        rank = nil
        name = str
      end
    end
    [rank, name]
  end

end
