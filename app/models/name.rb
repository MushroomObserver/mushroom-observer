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
    self.rss_log.add(self.unique_text_name, false)
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
  
  def self.find_names(in_str, rank=nil)
    name = in_str.strip
    if ['Unknown', 'unknown'].member? in_str
      name = "Fungi"
    end
    if rank
      Name.find(:all, :conditions => ["rank = :rank and (search_name = :name or text_name = :name)", {:rank => rank, :name => name}])
    else
      Name.find(:all, :conditions => ["search_name = :name or text_name = :name", {:name => name}])
    end
  end
  
  def self.make_species(genus, species)
    Name.make_name :Species, sprintf('%s %s', genus, species), :display_name => sprintf('__%s %s__', genus, species)
  end

  def self.make_genus(text_name)
    Name.make_name(:Genus, text_name,
                   :display_name => sprintf('__%s__', text_name),
                   :observation_name => sprintf('__%s sp.__', text_name),
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
    if in_str == 'Unknown'
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
          matches = Name.find(:all, :conditions => "text_name = '%s' and author is null" % text_name)
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
          if name.author.nil? and author
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
  def self.parse_above_species(in_str)
    results = nil
    match = ABOVE_SPECIES_PAT.match(in_str)
    if match
      search_name = "%s sp." % match[1]
      results = [match[1], "__%s__" % match[1], "__%s__" % search_name, search_name, nil]
    end
    results
  end
  
  # <Genus> sp. (or other higher rank)
  def self.parse_sp(in_str)
    results = nil
    match = SP_PAT.match(in_str)
    if match
      search_name = "%s sp." % match[1]
      results = [match[1], "__%s__" % match[1], "__%s__" % search_name, search_name, nil]
    end
    results
  end
  
  # <Genus> <species>
  def self.parse_species(in_str)
    results = nil
    match = SPECIES_PAT.match(in_str)
    if match
      display_name = "__%s %s__" % [match[1], match[2]]
      text_name = "%s %s" % [match[1], match[2]]
      results = [text_name, display_name, display_name, text_name, match[1]]
    end
    results
  end
  
  # <Genus> <species> subsp. <subspecies>
  def self.parse_subspecies(in_str)
    results = nil
    match = SUBSPECIES_PAT.match(in_str)
    if match
      text_name = "%s %s subsp. %s" % [match[1], match[2], match[4]]
      display_name = "__%s %s__ subsp. __%s__" % [match[1], match[2], match[4]]
      results = [text_name, display_name, display_name, text_name,
                 "%s %s" % [match[1], match[2]]]
    end
    results
  end
  
  # <Genus> <species> var. <subspecies>
  def self.parse_variety(in_str)
    results = nil
    match = VARIETY_PAT.match(in_str)
    if match
      text_name = "%s %s var. %s" % [match[1], match[2], match[4]]
      display_name = "__%s %s__ var. __%s__" % [match[1], match[2], match[4]]
      results = [text_name, display_name, display_name, text_name,
                 "%s %s" % [match[1], match[2]]]
    end
    results
  end
    
  # <Genus> <species> f. <subspecies>
  def self.parse_form(in_str)
    results = nil
    match = FORM_PAT.match(in_str)
    if match
      text_name = "%s %s f. %s" % [match[1], match[2], match[4]]
      display_name = "__%s %s__ f. __%s__" % [match[1], match[2], match[4]]
      results = [text_name, display_name, display_name, text_name,
                 "%s %s" % [match[1], match[2]]]
    end
    results
  end
  
  # <Taxon> group
  def self.parse_group(in_str)
    results = nil
    match = GROUP_PAT.match(in_str)
    if match
      name_str = match[1]
      results = parse_above_species(name_str)
      results = parse_species(name_str) if results.nil?
      results = parse_subspecies(name_str) if results.nil?
      results = parse_variety(name_str) if results.nil?
      results = parse_form(name_str) if results.nil?
    end
    if results
      text_name, display_name, observation_name, search_name, parent_name = results
      results = [text_name + " group", display_name + " group",
                 observation_name + " group", search_name + "group", text_name]
    end
    results
  end
  
  # Throws a RuntimeError with the error message if unsuccessful in anyway 
  def change_text_name(in_str, in_author, in_rank)
    common_errors(in_str)
    results = nil
    author = in_author.strip
    rank = in_rank.to_sym
    if Name.ranks_above_species.member? rank
      results = Name.parse_above_species(in_str)
    elsif :Species == rank
      results = Name.parse_species(in_str)
    elsif :Subspecies == rank
      results = Name.parse_subspecies(in_str)
    elsif :Variety == rank
      results = Name.parse_variety(in_str)
    elsif :Form == rank
      results = Name.parse_form(in_str)
    elsif :Group == rank
      results = Name.parse_group(in_str)
    elsif
      raise "Unrecognized rank, %s" % rank
    end
    if results.nil?
      raise "%s is invalid for the rank %s" % [in_str, rank]
    end
    # results must be set
    text_name, display_name, observation_name, search_name, parent_name = results
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
    matches = []
    if author != ''
      matches = Name.find(:all, :conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
      name = "%s %s" % [text_name, author]
    else
      matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
      name = text_name
    end
    for m in matches
      if m.id != self.id
        # In theory this should ask for a merge.  For now it's just an error.
        raise "The name, %s, is already in use" % name
      end
    end
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

  def valid_synonyms
    result = []
    synonym = self.synonym
    if synonym
      for n in synonym.names
        result.push(n) unless n.deprecated
      end
    end
    return result
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
