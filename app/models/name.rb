#
#  Model to describe a single scientific name.  The related class Synonym,
#  which can own multiple Name's, more accurately embodies the abstract concept
#  of a species.  A Name, on the other hand, refers to a single epithet, in a
#  single sense -- that is, a unique combination of genus, species, and author.
#  (Name also embraces infraspecies and extrageneric taxa as well.) 
#
#  The Name object's basic properties are:
#
#  1. has a name (several different formats, see below)
#  2. has an author (authority who first used this name in this sense)
#  3. has a citation (publication name was first used in)
#  4. has notes (there are plans for expanding this concept)
#  5. has a rank (e.g. :Genus, :Species, etc.)
#  6. can be deprecated (separate from synonymy)
#  7. has synonyms (i.e. can be one of a group of Name's owned by a Synonym)
#  8. belongs to a User (who created it originally)
#  9. has a history -- version number and asscociated PastLocation's
#  10. has an RssLog
#
#  Name Formats:
#    text_name           Plain text: "Xxx yyy"         "Xxx"             "Fungi"
#    search_name         Plain text: "Xxx yyy Author"  "Xxx sp. Author"  "Fungi sp."
#    display_name        Textilized: "Xxx yyy Author"  "Xxx Author"      "Kingdom of Fungi"
#    observation_name    Textilized: "Xxx yyy Author"  "Xxx sp. Author"  "Fungi sp."
#
#  Regexps: (in "English")
#    ABOVE_SPECIES_PAT   <Xxx>
#    SP_PAT              <Xxx species|sp.>
#    SPECIES_PAT         <Xxx yyy>
#    SUBSPECIES_PAT      <Xxx yyy subspecies|subsp|ssp|s. yyy>
#    VARIETY_PAT         <Xxx yyy variety|var|v. yyy>
#    FORM_PAT            <Xxx yyy forma|form|f. yyy>
#    AUTHOR_PAT          <Any-of-the-above Author...>  (author may have trailing space)
#    SENSU_PAT           <Whatever sensu zzz>          (sensu and zzz grouped together)
#    GROUP_PAT           <Whatever group|gr|gp.>
#
#  Notes on Regexps:
#    Extra whitespace allowed on ends and in middle.
#    <Xxx> can have dashes; <yyy> can also have double-quotes; <Zzz> is any
#      non-whitespace; <Whatever> is anything at all starting uppercase.
#    <Author> is determined to start at the second uppercase letter or any
#      punctuation mark not allowed in the taxa patterns.
#    Each word above is grouped separately and sequentially, except as noted.
#
#  These methods return symbols:
#    Name.all_ranks              :Form to :Kingdom, then :Group
#    Name.ranks_above_species    :Genus to :Kingdom
#    Name.names_for_unknown      "Unknown", "unknown", ""
#    Name.unknown                Name instance used for "unknown".
#
#  RSS Log:
#    log(str)
#    orphan_log(str)
#
#  Look Up or Create Names:
#    Name.find_names             Look up Names by text_name and search_name.
#    Name.names_from_string      Look up Name, create it, return it and parents.
#    Name.make_name              (used by names_from_string)
#    Name.create_name            (used by make_name)
#    Name.make_species           (not used by anyone)
#    Name.make_genus             (not used by anyone)
#    Name.find_name              (not used by anyone)
#    children                    Return array of child name objects.
#                                (only works for genera and species)
#
#  Parsing Methods:              (These are only used within this file.)
#    Name.parse_name             Parse arbitrary taxon, return parts.
#    Name.parse_by_rank          Parse taxon of given rank, return parts.
#    Name.parse_above_species    Parse "Xxx".
#    Name.parse_sp               Parse "Xxx sp.".
#    Name.parse_species          Parse "Xxx yyy".
#    Name.parse_subspecies       Parse "Xxx yyy subsp. zzz".
#    Name.parse_variety          Parse "Xxx yyy var. zzz".
#    Name.parse_form             Parse "Xxx yyy f. zzz".
#    Name.parse_group            Parse "Whatever group".
#    Name.parse_author           Extract author from string.
#    Name.parse_below_species    (used by parse_subspecies/variety/form)
#
#  Making Changes:
#    change_author               Changes author.
#    change_deprecated           Changes deprecation status.
#    change_text_name            Changes name.
#    Name.replace_author         (used by change_author)
#    check_for_repeats           (used by change_text_name)
#    common_errors               (used by change_text_name)
#
#  Synonyms:
#    approved_synonyms
#    sort_synonyms
#    clear_synonym
#    merge_synonyms
#
#  Random Helpers and Others:
#    has_notes?                  Does this name have any notes?
#    status                      Is this name deprecated?
#    prepend_notes               Add notes at the top of the existing notes.
#    Name.format_string          (used all over this file)
#
################################################################################

class Name < ActiveRecord::Base
  has_many :observations
  has_many :past_names
  has_many :namings
  has_one :rss_log
  belongs_to :user
  belongs_to :synonym

  # Creates RSS log as necessary.
  # Returns: nothing.
  def log(msg)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg, true)
  end

  # Creates RSS log as necessary.
  # Returns: nothing.
  def orphan_log(entry)
    self.log(entry) # Ensures that self.rss_log exists
    self.rss_log.species_list = nil
    self.rss_log.add(self.search_name, false)
  end

########################################

  # Patterns
  ABOVE_SPECIES_PAT = /^\s*([A-Z][a-z\-]+)\s*$/
  SP_PAT = /^\s*([A-Z][a-z\-]+)\s+(sp.|species)\s*$/
  SPECIES_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\-"]+)\s*$/
  SUBSPECIES_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\-"]+)\s+(subspecies|subsp|ssp|s)\.?\s+([a-z\-"]+)\s*$/
  VARIETY_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\-"]+)\s+(variety|var|v)\.?\s+([a-z\-"]+)\s*$/
  FORM_PAT = /^\s*([A-Z][a-z\-]+)\s+([a-z\-"]+)\s+(forma|form|f)\.?\s+([a-z\-"]+)\s*$/
  AUTHOR_PAT = /^\s*([A-Z][a-z\-\s\.]+[a-z])\s+(([^a-z"]|auct\.).*)$/ # May have trailing \s
  SENSU_PAT = /^\s*([A-Z].*)\s+(sensu\s+\S+)\s*$/
  GROUP_PAT = /^\s*([A-Z].*)\s+(group|gr|gp)\.?\s*$/

########################################

  # Returns: array of symbols, from :Form to :Kingdom, then :Group.
  def self.all_ranks()
    [:Form, :Variety, :Subspecies, :Species, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Group]
  end

  # Returns: array of symbols, from :Genus to :Kingdom.
  def self.ranks_above_species()
    [:Genus, :Family, :Order, :Class, :Phylum, :Kingdom]
  end

  # Returns: array of strings: "Unknown", "unknown", and "".
  def self.names_for_unknown()
    ['Unknown', 'unknown', '']
  end

  # Returns: "unknown" Name instance.
  def self.unknown
    Name.find(:first, :conditions => ['text_name = ?', 'Fungi'])
  end

  # Textilize a string: itallicize at least, and boldify it unless deprecated.
  # Returns: an adulterated copy of the string.
  # This is used throughout this file and nowhere else.
  def self.format_string(str, deprecated)
    boldness = '**'
    # boldness = ''
    if deprecated
      boldness = ''
    end
    "#{boldness}__#{str}__#{boldness}"
  end

########################################

  # Look up names with a given text_name or search_name.
  # By default tries to weed out deprecated names, but if that results in an
  # empty set, then it returns the deprecated ones.  Both deprecated and
  # non-deprecated names can be returned by setting deprecated to true.
  # Returns: array of Name instances.
  def self.find_names(in_str, rank=nil, deprecated=false)
    name = in_str.strip
    if names_for_unknown.member? name
      name = "Fungi"
    end
    deprecated_condition = ''
    unless deprecated
      deprecated_condition = 'deprecated = 0 and '
    end

    # Look up the name.  Can get multiple matches if there are multiple names with the same name but different authors.
    # (found via searching on text_name).  However, if the user provides an explicit author, there should be no way to
    # get multiple matches.
    if rank
      result = Name.find(:all, :conditions => ["#{deprecated_condition}rank = :rank and (search_name = :name or text_name = :name)",
                                               {:rank => rank, :name => name}])
      if (result == []) and Name.ranks_above_species.member?(rank.to_sym)
        # I think this serves the purpose of allowing user to search on "Genus Author", in which case (I believe)
        # the desired matching name will have text_name="Genus" and search_name="Genus sp. Author", neither of which
        # would match the above statement without the "sp." being added. [-JPH 20080227]
        name.sub!(' ', ' sp. ')
        result = Name.find(:all, :conditions => ["#{deprecated_condition}rank = :rank and (search_name = :name or text_name = :name)",
                                                 {:rank => rank, :name => name}])
      end
      result
    else
      # Note: this will fail to find "Genus Author" (see above).  Just don't do it, leave the darned author off, for god's sake.
      result = Name.find(:all, :conditions => ["#{deprecated_condition}(search_name = :name or text_name = :name)", {:name => name}])
    end

    if result == []
      # If provided a name complete with author, then check if that name exists in the database without the author.
      name, author = Name.parse_author(in_str)
      if !author.nil?
        # Don't check text_name because we don't want to match a name that has a different author.
        # (Note that name already has the "sp." inserted in the case of ranks above species.)
        if rank
          result = Name.find(:all, :conditions => ["#{deprecated_condition}rank = :rank and search_name = :name",
                                                   {:rank => rank, :name => name}])
        else
          result = Name.find(:all, :conditions => ["#{deprecated_condition}search_name = :name", {:name => name}])
        end
        # If we find it, add the author to it.  Probably should ask the user for confirmation, but that looks really tricky.
        if result.length == 1
          result.first.change_author author
          result.first.save
        end
      end
    end

    # No names that aren't deprecated, so try for ones that are deprecated
    if result == [] and not deprecated
      result = self.find_names(in_str, rank, true)
    end
    result
  end

  # Lookup a species by genus and species, creating if necessary.
  # Returns: Name instance, NOT SAVED!
  def self.make_species(genus, species, deprecated = false)
    Name.make_name :Species, sprintf('%s %s', genus, species), :display_name => format_string("#{genus} #{species}", deprecated)
  end

  # Lookup a genus, creating if necessary.
  # Returns: Name instance, NOT SAVED!
  def self.make_genus(text_name, deprecated = false)
    Name.make_name(:Genus, text_name,
                   :display_name => format_string(text_name, deprecated),
                   :observation_name => format_string("#{text_name} sp.", deprecated),
                   :search_name => text_name + ' sp.')
  end

#   [This isn't used by anyone.  -JPH 20071125]
#   def self.find_name(rank, text_name)
#     conditions = ''
#     if rank
#       conditions = "rank = '%s'" % rank
#     end
#     if text_name
#       if conditions
#         conditions += ' and '
#       end
#       conditions += "text_name = '%s'" % text_name
#     end
#     Name.find(:all, :conditions => conditions)
#   end

  # Create name given all the various name formats, etc.
  # Used only by make_name().
  # Returns: Name instance, NOT SAVED!
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

  # Lookup a name, creating it as necessary.  Requires rank, text_name,
  # and display name, at least, supplying defaults for search_name and
  # observation_name, and leaving author blank by default. Requires an
  # exact match of both name and author.
  # Returns:
  #   zero or one match: a Name instance, NOT SAVED!
  #   multiple matches: nil
  # Only used by make_species(), make_genus(), and names_from_string().
  def self.make_name(rank, text_name, params)
    display_name = params[:display_name] || text_name
    observation_name = params[:observation_name] || display_name
    search_name = params[:search_name] || text_name
    author = params[:author]
    result = nil
    if rank
      matches = Name.find(:all, :conditions => ['search_name = ?', search_name])
      if matches == []
        result = Name.create_name(rank, text_name, author, display_name, observation_name, search_name)
      elsif matches.length == 1
        result = matches.first
      end
    end
    result
  end

  # Parses a string, creates a Name for it and all its ancestors (if any don't
  # already exist), returns it in an array (genus first, then species and
  # variety).  (Ancestors only go back to genus at the moment; I'm not sure
  # this will ever change for this routine, as it is purely mechanical.)
  # Note: check if any results are missing an id to determine which are new.
  # Returns: array of Name instances, NOT SAVED! (both new names and pre-
  #   existing names which could potentially have changes such as author)
  def self.names_from_string(in_str)
    result = []
    if names_for_unknown.member? in_str
      result.push Name.unknown
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
        if author.nil? || author == ''
          matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
        else
          matches = Name.find(:all, :conditions => "search_name = '%s'" % search_name)
          if matches == []
            matches = Name.find(:all, :conditions => "text_name = '%s' and (author is null or author = '')" % text_name)
          end
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
          if (name.author.nil? or name.author == '') and !author.nil? and author != ""
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

  def children
    result = []
    if self.rank == :Genus
      result = Name.find(:all, :conditions => "text_name like '#{self.text_name} %' and rank = 'species'",
        :order => "text_name asc")
    elsif self.rank == :Species
      result = Name.find(:all, :conditions => "text_name like '#{self.text_name} %' and
        (rank = 'Subspecies' or rank = 'Variety' or rank = 'Form')",
        :order => "text_name asc")
    end
    result
  end

  # Currently just parses the text name to find Genus and possible Species.  Ultimately
  # this should get high level clades, but I don't have a good source for that data yet.
  def ancestors
    result = []
    if [:Form, :Variety, :Subspecies, :Species].member?(self.rank)
      tokens = self.text_name.split(' ')
      result = Name.find(:all, :conditions => "text_name like '#{tokens[0]}' and rank = 'genus'",
        :order => "text_name asc")
      if self.rank != :Species
        result += Name.find(:all, :conditions => "text_name like '#{tokens[0]} #{tokens[1]}' and rank = 'species'",
        :order => "text_name asc")
      end
    end
    result
  end

########################################

  # Parse a string, return the following array:
  #  0: text_name         "Xx yy v. zz"         "Xx yy"         "Xx"
  #  1: display_name      "Xx yy v. zz Author"  "Xx yy Author"  "Xx sp. Author"
  #  2: observation_name  "Xx yy v. zz Author"  "Xx yy Author"  "Xx Author"
  #  3; search_name       "Xx yy v. zz Author"  "Xx yy Author"  "Xx sp. Author"
  #  4: parent_name
  #  5: rank              :Variety              :Species        :Genus
  #  6: author            "Author"              "Author"        "Author"
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

  # Pick off author, return [name, author]
  def self.parse_author(in_str)
    name = in_str
    author = nil
    match = SENSU_PAT.match(in_str)
    if match.nil?
      match = AUTHOR_PAT.match(in_str)
    end
    if match
      name = match[1]
      author = match[2].strip # Due to possible trailing \s
    end
    [name, author]
  end

  # The following methods all return the following array:
  #  0: text_name
  #  1: display_name
  #  2: observation_name
  #  3; search_name
  #  4: parent_name

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

  # <Genus> <species> but reject <Genus> section
  def self.parse_species(in_str, deprecated=false)
    results = nil
    match = SPECIES_PAT.match(in_str)
    if match and (match[2] != 'section')
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

  # Specified rank.
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
      raise "Unrecognized rank, %s." % rank
    end
    if results.nil?
      raise "%s is invalid for the rank %s." % [in_str, rank]
    end
    results
  end

########################################

  # Changes author.  Updates formatted names, as well.
  # Returns: author, NOT SAVED!
  def change_author(new_author)
    old_author = self.author
    self.author = new_author
    self.display_name     = Name.replace_author(self.display_name,     old_author, new_author)
    self.observation_name = Name.replace_author(self.observation_name, old_author, new_author)
    self.search_name      = Name.replace_author(self.search_name,      old_author, new_author)
  end

  # Used by change_author().
  def self.replace_author(str, old_author, new_author)
    result = str
    if old_author
      ri = result.rindex " " + old_author
      if ri and (ri + old_author.length + 1 == result.length)
        result = result[0..ri].strip
      end
    end
    if new_author
      result += " " + new_author
    end
    return result
  end

  # Changes deprecated status.  Updates formatted names, as well.
  # Returns: value, NOT SAVED!
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

  # Changes the name, creates parents as necessary, ... [This doesn't seem to
  # be all kosher.  It used an undefined variable "rank", and it doesn't add
  # the author to observation_name and search_name in some cases, whereas
  # parse_name always does.  This needs to be looked at.  -JPH 20071125]
  # Throws a RuntimeError with the error message if unsuccessful in any way.
  # Returns: nothing, NOT SAVED!
  def change_text_name(in_str, new_author, new_rank)
    Name.common_errors(in_str)
    results = nil
    new_author = new_author.strip
    new_text_name, new_display_name, new_observation_name, new_search_name, parent_name =
      Name.parse_by_rank(in_str, new_rank, self.deprecated)
    if (parent_name and Name.find(:all, :conditions => "text_name = '%s'" % parent_name) == [])
      names = Name.names_from_string(parent_name)
      if names.last.nil?
        raise "Unable to create the name %s." % parent_name
      else
        for n in names
          n.user_id = self.user_id
          n.save
        end
      end
    end
    # Name.check_for_repeats(new_text_name, new_author)
    if new_author
      new_display_name     = "%s %s" % [new_display_name, new_author]
      new_observation_name = "%s %s" % [new_observation_name, new_author]
      new_search_name      = "%s %s" % [new_search_name, new_author]
    end
    self.rank             = new_rank
    self.author           = new_author
    self.text_name        = new_text_name
    self.display_name     = new_display_name
    self.observation_name = new_observation_name
    self.search_name      = new_search_name
  end

  # Used by change_text_name().
  def self.common_errors(in_str)
    result = true
    match = /^[Uu]nknown|\sspecies$|\ssp.?\s*$|\ssensu\s/.match(in_str)
    if match
      raise "%s is an invalid name." % in_str
    end
  end

  # Used by change_text_name().
  def self.check_for_repeats(text_name, author)
    matches = []
    if author != ''
      matches = Name.find(:all, :conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
    else
      matches = Name.find(:all, :conditions => "text_name = '%s'" % text_name)
    end
    for m in matches
      if m.id != self.id
        raise "The name, %s, is already in use." % text_name
      end
    end
  end

########################################

  # Get list of synonyms that aren't deprecated (including potentially itself).
  # Returns: array of Name instances.
  def approved_synonyms
    result = []
    if self.synonym
      for n in self.synonym.names
        result.push(n) unless n.deprecated
      end
    end
    return result
  end

  # Get list of both deprecated and valid synonyms (NOT including itself).
  # (Each list is unsorted, however.)
  # Returns: pair of arrays of Name instances.
  def sort_synonyms
    accepted_synonyms = []
    deprecated_synonyms = []
  	if self.synonym
  	  for n in self.synonym.names
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

  # Removes this name from its old synonym list.  It destroys the synonym
  # list entirely if there's only one name left in it afterword.
  # Returns: nothing.  Saves changes.
  def clear_synonym
    if self.synonym
      names = self.synonym.names
      if names.length <= 2 # Get rid of the synonym
        for n in names
          n.synonym = nil
          n.save
        end
        self.synonym.destroy
      else # Just clear this name
        self.synonym = nil
        self.save
      end
    end
  end

  # Makes two names synonymous.  If either name already has a list of synonyms,
  # it will merge the synonym lists into a single list.
  # Returns: nothing.  Saves changes.
  def merge_synonyms(name)
    if self.synonym.nil?
      if name.synonym.nil? # No existing synonym
        self.synonym = Synonym.new
        self.synonym.created = Time.now
        self.save
        self.synonym.transfer(name)
      else # Just name has a synonym
        name.synonym.transfer(self)
      end
    else # Self has a synonym
      if name.synonym.nil? # but name doesn't
        self.synonym.transfer(name)
      else # Both have synonyms so merge
        for n in name.synonym.names
          self.synonym.transfer(n)
        end
      end
    end
  end

########################################

  # Returns boolean.
  def has_notes?()
    self.notes && (self.notes != '')
  end

  # Is this name deprecated?
  # Returns "Deprecated" or "Valid".
  def status
    if self.deprecated
      "Deprecated"
    else
      "Valid"
    end
  end

  # Stick some (Textile) notes onto the top of existing notes.
  # Returns nothing.  Saves change.
  def prepend_notes(str)
    if !self.notes.nil? && self.notes != ""
      self.notes = str + "<br>\n\n" + self.notes
    else
      self.notes = str
    end
    self.save
  end
end
