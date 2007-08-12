class Name < ActiveRecord::Base
  has_many :observations
  has_many :past_names
  has_one :rss_log
  belongs_to :user
  belongs_to :synonym

  def log(msg)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg, true)
  end
  
  def orphan_log(entry)
    self.log(entry) # Ensures that self.rss_log exists
    self.rss_log.species_list = nil
    self.rss_log.add(self.search_name, false)
  end

  # Patterns 
  ABOVE_SPECIES_PAT = /^\s*([A-Z][a-z\-]+)\s*$/
  SP_PAT = /^\s*([A-Z][a-z\-]+)\s+(sp.|species)\s*$/
  SPECIES_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\-"]+)\s*$/
  SUBSPECIES_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\_"]+)\s+(subspecies|subsp|s)\.?\s+([a-z\-"]+)\s*$/
  VARIETY_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\_"]+)\s+(variety|var|v)\.?\s+([a-z\-"]+)\s*$/
  FORM_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\_"]+)\s+(forma|form|f)\.?\s+([a-z\-"]+)\s*$/
  AUTHOR_PAT = /^\s*([A-Z][a-z\-\s\.]+[a-z])\s+([^a-z"].*)$/ # May have trailing \s
  SENSU_PAT = /^\s*([A-Z].*)\s+(sensu\s+\S+)\s*$/
  GROUP_PAT = /^\s*([A-Z].*)\s+(group|gr|gp)\.?\s*$/
  
  
  def self.all_ranks()
    [:Form, :Variety, :Subspecies, :Species, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Group]
  end
  
  def self.ranks_above_species()
    [:Genus, :Family, :Order, :Class, :Phylum, :Kingdom]
  end
  
  def self.names_for_unknown()
    ['Unknown', 'unknown', '']
  end
  
  # By default tries to weed out deprecated names, but if that results in an empty set,
  # then it returns the deprecated ones.  Both deprecated and non-deprecated names can
  # be returned by setting deprecated to true.
  def self.find_names(in_str, rank=nil, deprecated=false)
    name = in_str.strip
    if names_for_unknown.member? name
      name = "Fungi"
    end
    deprecated_condition = ''
    unless deprecated
      deprecated_condition = 'deprecated = 0 and '
    end
    if rank
      result = Name.find(:all, :conditions => ["#{deprecated_condition}rank = :rank and (search_name = :name or text_name = :name)",
                                               {:rank => rank, :name => name}])
      if (result == []) and Name.ranks_above_species.member?(rank.to_sym)
        name.sub!(' ', ' sp. ')
        result = Name.find(:all, :conditions => ["#{deprecated_condition}rank = :rank and (search_name = :name or text_name = :name)",
                                                 {:rank => rank, :name => name}])
      end
      result
    else
      result = Name.find(:all, :conditions => ["#{deprecated_condition}(search_name = :name or text_name = :name)", {:name => name}])
    end
    
    # No names that aren't deprecated, so try for ones that are deprecated
    if result == [] and not deprecated
      result = self.find_names(in_str, rank, true)
    end
    result
  end
  
  def self.format_string(str, deprecated)
    boldness = '**'
    # boldness = ''
    if deprecated
      boldness = ''
    end
    "#{boldness}__#{str}__#{boldness}"
  end
  
  def self.make_species(genus, species, deprecated = false)
    Name.make_name :Species, sprintf('%s %s', genus, species), :display_name => format_string("#{genus} #{species}", deprecated)
  end

  def self.make_genus(text_name, deprecated = false)
    Name.make_name(:Genus, text_name,
                   :display_name => format_string(text_name, deprecated),
                   :observation_name => format_string("#{text_name} sp.", deprecated),
                   :search_name => text_name + ' sp.')
  end

  def self.find_name(rank, text_name)
    conditions = ''
    if rank
      conditions = "rank = '%s'" % rank
    end
    if text_name
      if conditions
        conditions += ' and '
      end
      conditions += "text_name = '%s'" % text_name
    end
    Name.find(:all, :conditions => conditions)
  end
  
  def self.create_name(rank, text_name, author, display_name, observation_name, search_name)
    result = Name.new
    now = Time.new
    result.created = now
    result.modified = now
    result.rank = rank
    result.text_name = text_name
    result.author = author
    result.display_name = display_name
    result.observation_name = observation_name
    result.search_name = search_name
    result
  end
  
  def self.make_name(rank, text_name, params)
    display_name = params[:display_name] || text_name
    observation_name = params[:observation_name] || display_name
    search_name = params[:search_name] || text_name
    author = params[:author]
    result = nil
    if rank
      matches = Name.find(:all, :conditions => sprintf("search_name = '%s'", search_name))
      if matches == []
        result = Name.create_name(rank, text_name, author, display_name, observation_name, search_name)
      elsif matches.length == 1
        result = matches.first
      end
    end
    result
  end
  
  def self.names_from_string(in_str)
    result = []
    if names_for_unknown.member? in_str
      result = Name.find_name(:Kingdom, 'Fungi')
    else
      str = in_str.gsub(" near ", " ")
      parse = parse_name(str)
      if parse
        text_name, display_name, observation_name, search_name, parent_name, rank, author = parse
        if parent_name
          result = Name.names_from_string(parent_name)
        end
        matches = []
        name = text_name
        if author != ''
          matches = Name.find(:all, :conditions => "search_name = '%s'" % search_name)
        end
        if matches == []
          matches = Name.find(:all, :conditions => "text_name = '%s' and (author is null or author = '')" % text_name)
        end
        match_count = matches.length
        if match_count == 0
          name = Name.make_name(rank, text_name,
                                :display_name => display_name,
                                :observation_name => observation_name,
                                :search_name => search_name,
                                :author => author)
          result.push name
        elsif match_count == 1
          name = matches[0]
          if (name.author.nil? or name.author == '') and author
            name.change_author author
          end
          result.push name
        else
          result.push nil
        end
      end
    end
    result
  end

  def self.replace_author(str, old_author, author)
    name = str
    if old_author
      ri = name.rindex " " + old_author
      if ri and (ri + old_author.length + 1 == name.length)
        name = name[0..ri].strip
      end
    end
    if author
      name += " " + author
    end
    return name
  end
  
  def change_author(author)
    old_author = self.author
    self.display_name = Name.replace_author(self.display_name, old_author, author)
    self.observation_name = Name.replace_author(self.observation_name, old_author, author)
    self.search_name = Name.replace_author(self.search_name, old_author, author)
    self.author = author
  end
  
  def change_deprecated(value)
    # Remove any boldness that might be there
    self.display_name.gsub!(/\*\*([^*]+)\*\*/, '\1')
    self.observation_name.gsub!(/\*\*([^*]+)\*\*/, '\1')
    unless value
      # Add boldness
      self.display_name.gsub!(/(__[^_]+__)/, '**\1**')
      if self.display_name != self.observation_name
        self.observation_name.gsub!(/(__[^_]+__)/, '**\1**')
      end
    end
    self.deprecated = value
  end

  def common_errors(in_str)
    result = true
    match = /^[Uu]nknown|\sspecies$|\ssp.?\s*$|\ssensu\s/.match(in_str)
    if match
      raise "%s is an invalid name" % in_str
    end
  end
  
  
  def self.parse_name(str)
    (name, author) = parse_author(str)
    rank = :Group
    parse = parse_group(name)
    if parse.nil?
      rank = :Genus
      parse = parse_sp(name)
    end
    if parse.nil?
      rank = :Species
      parse = parse_species(name)
    end
    if parse.nil?
      rank = :Subspecies
      parse = parse_subspecies(name)
    end
    if parse.nil?
      rank = :Variety
      parse = parse_variety(name)
    end
    if parse.nil?
      rank = :Form
      parse = parse_form(name)
    end
    if parse.nil?
      rank = :Genus
      parse = parse_above_species(name)
    end
    if parse
      if author
        author_str = " " + author
        parse[1] += author_str
        parse[2] += author_str
        parse[3] += author_str
      end
      parse += [rank, author]
    end
    return parse
  end
  
  def self.parse_author(in_str)
    name = in_str
    author = nil
    match = SENSU_PAT.match(in_str)
    if match.nil?
      match = AUTHOR_PAT.match(in_str)
    end
    if match
      name = match[1]
      author = match[2].strip # Due to possible training \s
    end
    [name, author]
  end
  
  # parse_* return: text_name, display_name, observation_name, search_name, parent_name
  
  # <Genus> (or other higher rank)
  def self.parse_above_species(in_str, deprecated=false)
    results = nil
    match = ABOVE_SPECIES_PAT.match(in_str)
    if match
      search_name = "%s sp." % match[1]
      results = [match[1], format_string(match[1], deprecated), format_string(search_name, deprecated), search_name, nil]
    end
    results
  end
  
  # <Genus> sp. (or other higher rank)
  def self.parse_sp(in_str, deprecated=false)
    results = nil
    match = SP_PAT.match(in_str)
    if match
      search_name = "#{match[1]} sp."
      results = [match[1], format_string(match[1], deprecated), format_string(search_name, deprecated), search_name, nil]
    end
    results
  end
  
  # <Genus> <species>
  def self.parse_species(in_str, deprecated=false)
    results = nil
    match = SPECIES_PAT.match(in_str)
    if match
      text_name = "#{match[1]} #{match[2]}"
      display_name = format_string(text_name, deprecated)
      results = [text_name, display_name, display_name, text_name, match[1]]
    end
    results
  end
  
  def self.parse_below_species(pat, in_str, term, deprecated)
    results = nil
    match = pat.match(in_str)
    if match
      sp_name = "#{match[1]} #{match[2]}"
      sub_name = match[4]
      text_name = "#{sp_name} #{term} #{sub_name}"
      display_name = "#{format_string(sp_name, deprecated)} #{term} #{format_string(sub_name, deprecated)}"
      results = [text_name, display_name, display_name, text_name, sp_name]
    end
    results
  end

  # <Genus> <species> subsp. <subspecies>
  def self.parse_subspecies(in_str, deprecated=false)
    parse_below_species(SUBSPECIES_PAT, in_str, 'subsp.', deprecated)
  end
  
  # <Genus> <species> var. <subspecies>
  def self.parse_variety(in_str, deprecated=false)
    parse_below_species(VARIETY_PAT, in_str, 'var.', deprecated)
  end
    
  # <Genus> <species> f. <subspecies>
  def self.parse_form(in_str, deprecated=false)
    parse_below_species(FORM_PAT, in_str, 'f.', deprecated)
  end
  
  # <Taxon> group
  def self.parse_group(in_str, deprecated=false)
    results = nil
    match = GROUP_PAT.match(in_str)
    if match
      name_str = match[1]
      results = parse_above_species(name_str, deprecated)
      results = parse_species(name_str, deprecated) if results.nil?
      results = parse_subspecies(name_str, deprecated) if results.nil?
      results = parse_variety(name_str, deprecated) if results.nil?
      results = parse_form(name_str, deprecated) if results.nil?
    end
    if results
      text_name, display_name, observation_name, search_name, parent_name = results
      results = [text_name + " group", display_name + " group",
                 observation_name + " group", search_name + "group", text_name]
    end
    results
  end
  
  def self.parse_by_rank(in_str, in_rank, in_deprecated)
    rank = in_rank.to_sym
    if ranks_above_species.member? rank
      results = parse_above_species(in_str, in_deprecated)
    elsif :Species == rank
      results = parse_species(in_str, in_deprecated)
    elsif :Subspecies == rank
      results = parse_subspecies(in_str, in_deprecated)
    elsif :Variety == rank
      results = parse_variety(in_str, in_deprecated)
    elsif :Form == rank
      results = parse_form(in_str, in_deprecated)
    elsif :Group == rank
      results = parse_group(in_str, in_deprecated)
    elsif
      raise "Unrecognized rank, %s" % rank
    end
    if results.nil?
      raise "%s is invalid for the rank %s" % [in_str, rank]
    end
    results
  end
  
  def mergable?()
    self.notes.nil? || (self.notes == '')
  end
  
  def check_for_repeats(text_name, author)
    matches = []
    if author != ''
      matches = Name.find(:all, :conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
    else
      matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
    end
    for m in matches
      if m.id != self.id
        raise "The name, %s, is already in use" % text_name
      end
    end
  end

  # Throws a RuntimeError with the error message if unsuccessful in anyway 
  def change_text_name(in_str, in_author, in_rank)
    common_errors(in_str)
    results = nil
    author = in_author.strip
    text_name, display_name, observation_name, search_name, parent_name = Name.parse_by_rank(in_str, in_rank, self.deprecated)
    if (parent_name and Name.find(:all, :conditions => "text_name = '%s'" % parent_name) == [])
      names = Name.names_from_string(parent_name)
      if names.last.nil?
        raise "Unable to create the name %s" % parent_name
      else
        for n in names
          n.user_id = user_id
          n.save
        end
      end
    end
    # check_for_repeats(text_name, author)
    self.rank = rank
    self.text_name = text_name
    self.author = author
    if author
      display_name = "%s %s" % [display_name, author]
      if [:Species, :Subspecies, :Variety, :Form].member? rank
        observation_name = "%s %s" % [observation_name, author]
        search_name = "%s %s" % [search_name, author]
      end
    end
    self.display_name = display_name
    self.observation_name = observation_name
    self.search_name = search_name
  end

  def approved_synonyms
    result = []
    synonym = self.synonym
    if synonym
      for n in synonym.names
        result.push(n) unless n.deprecated
      end
    end
    return result
  end
  
  def sort_synonyms
    accepted_synonyms = []
    deprecated_synonyms = []
    synonym = self.synonym
  	if synonym
  	  for n in synonym.names
  	    if (n != self)
  	      if n.deprecated
  	        deprecated_synonyms.push(n)
	        else
	          accepted_synonyms.push(n)
	        end
  	    end
  	  end
  	end
  	[accepted_synonyms, deprecated_synonyms]
  end
  	
  # Ensure that this Name has no synonyms by clearing the synonym
  # and destroying it if necessary
  def clear_synonym
    synonym = self.synonym
    if synonym
      names = synonym.names
      if names.length <= 2 # Get rid of the synonym
        for n in names
          n.synonym = nil
          n.save
        end
        synonym.destroy
      else # Just clear this name
        self.synonym = nil
        self.save
      end
    end
  end

  def merge_synonyms(name)
    synonym = self.synonym
    name_synonym = name.synonym
    if synonym.nil?
      if name_synonym.nil? # No existing synonym
        synonym = Synonym.new
        synonym.created = Time.now
        self.synonym = synonym
        self.save
        synonym.transfer(name)
      else # Just name has a synonym
        name_synonym.transfer(self)
      end
    else # self has a synonym
      if name_synonym.nil? # but name doesn't
        synonym.transfer(name)
      else # both have synonyms so merge
        for n in name_synonym.names
          synonym.transfer(n)
        end
      end
    end
  end
  
  def status
    if self.deprecated
      "Deprecated"
    else
      "Valid"
    end
  end
end
