#  Created by Nathan Wilson on 2007-06-08.
#  Copyright (c) 2007. All rights reserved.

class NameParse
  attr_reader :line_str
  attr_reader :name
  attr_reader :rank
  attr_reader :search_name
  attr_reader :comment
  attr_reader :synonym
  attr_reader :synonym_rank
  attr_reader :synonym_search_name
  attr_reader :synonym_comment

  # spl_line can be either:
  #   <name>
  #   <name> = <synonym>
  # with an optional [comment] at the end
  # and where <name> is one of
  #   <search_name>
  #   <rank> <search_name>
  # and <synonym> is either
  #   <synonym_search_name>
  #   <synonym_rank> <synonym_search_name>
  def initialize(spl_line)
    result = []
    name_str = ''
    @line_str = spl_line.strip.squeeze(" ")
    equal_pos = @line_str.index('=')
    if equal_pos
      @name = @line_str[0..equal_pos-1].strip
      @synonym = @line_str[equal_pos+1..-1].strip
      @synonym_comment = nil
      match = /^([^\[]*) \[(.*)\]$/.match(@synonym)
      if match
        @synonym = match[1]
        @synonym_comment = match[2]
      end
      (@synonym_rank, @synonym_search_name) = parse_rank(@synonym)
    else
      @name = @line_str
      @comment = nil
      @synonym = nil
      @synonym_rank = nil
      @synonym_search_name = nil
      match = /^([^\[]*) \[(.*)\]$/.match(@name)
      if match
        @name = match[1]
        @comment = match[2]
      end
    end
    (@rank, @search_name) = parse_rank(@name)
  end

  def has_synonym()
    @synonym != nil
  end
  
  def find_names()
    Name.find_names(@search_name, @rank)
  end
  
  def find_synonym_names()
    result = []
    if @synonym
      result = Name.find_names(@synonym_search_name, @synonym_rank)
    end
    result
  end
  
  def parse_rank(str)
    result = [nil, str]
    space_pos = str.index(' ')
    if space_pos
      rank = str[0..space_pos-1].to_sym
      if Name.all_ranks.member?(rank)
        result = [rank, str[space_pos..-1].strip]
      end
    end
    result
  end

end
