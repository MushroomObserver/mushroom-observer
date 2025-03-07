#!/usr/bin/env ruby
# frozen_string_literal: true

# Current:
#           text_name: Adelphella "sp-SW38"
#         search_name: Adelphella "sp-SW38" crypt. temp.
#        display_name: **__Adelphella "sp-SW38"__** crypt. temp.
#           sort_name: Adelphella {sp-SW38"  crypt. temp.                                                                                               
                                                                                                                                                      
# Desired:                                                                                                                                              
#           text_name: Adelphella sp. 'SW38'                                                                                                            
#         search_name: Adelphella sp. 'SW38' crypt. temp.                                                                                               
#        display_name: **__Adelphella__ sp. __'SW38'__** crypt. temp.                                                                                   
#           sort_name: Adelphella sp. {SW38'  crypt. temp.                                                                                              


def update
  # names = (Name.where(Name[:text_name].matches('%"%')) +
  # Name.where(Name[:text_name].matches("%'%"))).uniq
  count = 0
  Name.find_each do |name|
    name.skip_notify = true
    # puts(update_str(name.text_name, name.rank))
    # puts(update_str(name.search_name, name.rank))
    # puts(update_display_name(name.display_name, name.rank))
    # puts(update_str(name.sort_name, name.rank))
    # name.text_name = update_str(name.text_name, name.rank)
    # name.search_name = update_str(name.search_name, name.rank)
    # name.display_name = update_display_name(name.display_name, name.rank)
    # name.sort_name = Name.format_sort_name(name.text_name, name.author)
    # name.save
    # puts(name.id)
    parse = Name.parse_name(name.search_name)
    if parse
      if name.sort_name != parse.sort_name
        count += 1
        puts("#{count},#{name.id},#{name.sort_name},#{name.created_at}")
        name.sort_name = parse.sort_name
        name.save
      end
    else
      puts("BAD PARSE: #{name.id},#{name.search_name}")
    end
  end
end

def update_display_name(str, rank)
  update_str(str, rank, markup: "__")
end

def update_str(str, rank, markup: "")
  update_quotes(update_rank(str, rank, markup))
end

def update_quotes(str)
  debugger if str.nil?
  str.gsub('"', "'").gsub("''", "'")
end

RANK_TO_PREFIX = {
  "Form" => "f",
  "Variety" => "var",
  "Subspecies" => "subsp",
  "Species" => "sp",
  "Stirps" => "st",
  "Subsection" => "subsec",
  "Section" => "sec",
  "Subgenus" => "subg",
}

def update_rank(str, rank, markup)
  prefix = RANK_TO_PREFIX[rank]
  return str unless prefix

  result = replace_prefix(prefix, str)
  indicator = "#{markup} #{prefix}. #{markup}"
  return result if result.include?(indicator)

  result.sub(" ", indicator)
end

def replace_prefix(prefix, text)
  # This regex looks for single or double quotes followed by 
  # the specified prefix and a dash, then captures everything after
  # the dash to be preserved in the replacement
  pattern = /(['"])(#{Regexp.escape(prefix)})-(.*?)\1/
  
  # Replace with the quote, followed directly by the content after the dash, 
  # followed by the closing quote
  text.gsub(pattern, '\1\3\1')
end

update
