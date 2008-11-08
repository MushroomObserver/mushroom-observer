require_dependency 'acts_as_versioned_extensions'

################################################################################
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
#    display_name        in Textile: "Xxx yyy Author"  "Xxx Author"      "Kingdom of Fungi"
#    observation_name    in Textile: "Xxx yyy Author"  "Xxx sp. Author"  "Fungi sp."
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
#    ancestors                   Return array of taxa that contain this one.
#                                (only works for subgeneric taxa)
#    parents                     Return array of parent name objects.
#                                (only works for species and below)
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
  has_many :namings
  has_one :rss_log
  belongs_to :user
  belongs_to :synonym
  belongs_to :reviewer, :class_name => "User", :foreign_key => "reviewer_id"
  belongs_to :license

  acts_as_versioned(:class_name => 'PastName', :table_name => 'past_names')
  non_versioned_columns.push('created', 'synonym_id', 'num_views', 'last_view')
  ignore_if_changed('modified', 'user_id', 'review_status', 'reviewer_id', 'last_review', 'ok_for_export')
  # (note: ignore_if_changed is in app/models/acts_as_versioned_extensions)

  ABOVE_SPECIES_PAT = /^\s* ("?[A-Z][a-zë\-]+"?) \s*$/x
  SP_PAT            = /^\s* ("?[A-Z][a-zë\-]+"?) \s+ (sp\.?|species) \s*$/x
  SPECIES_PAT       = /^\s* ("?[A-Z][a-zë\-]+"?) \s+ ([a-zë\-\"]+) \s*$/x
  SUBSPECIES_PAT    = /^\s* ("?[A-Z][a-zë\-]+"?  \s+  [a-zë\-\"]+)    \s+ (?:subspecies|subsp|ssp|s)\.? \s+ ([a-zë\-\"]+) \s*$/x
  VARIETY_PAT       = /^\s* ("?[A-Z][a-zë\-]+"?  \s+  [a-zë\-\"]+ (?: \s+ (?:subspecies|subsp|ssp|s)\.? \s+ [a-zë\-\"]+)?)    \s+ (?:variety|var|v)\.? \s+ ([a-zë\-\"]+) \s*$/x
  FORM_PAT          = /^\s* ("?[A-Z][a-zë\-]+"?  \s+  [a-zë\-\"]+ (?: \s+ (?:subspecies|subsp|ssp|s)\.? \s+ [a-zë\-\"]+)? (?: \s+ (?:variety|var|v)\.? \s+ [a-zë\-\"]+)?) \s+ (?:forma|form|f)\.? \s+ ([a-zë\-\"]+) \s*$/x
  AUTHOR_PAT        = /^\s* ("?[A-Z][a-zë\-\s\.\"]+?[a-zë\"](?:\s+sp\.)?) \s+ (("?[^a-z"\s]|auct\.|van\sd[a-z]+\s[A-Z]).*) $/x   # (may have trailing space)
  SENSU_PAT         = /^\s* ("?[A-Z].*) \s+ (sens[u\.]\s+\S.*\S) \s*$/x
  GROUP_PAT         = /^\s* ("?[A-Z].*) \s+ (group|gr|gp)\.?     \s*$/x
  COMMENT_PAT       = /^\s* ([^\[\]]*)  \s+ \[(.*)\] \s*$/x

########################################

  # Returns: array of symbols.  Essentially a constant array.
  def self.all_review_statuses()
    [:unreviewed, :unvetted, :vetted, :inaccurate]
  end

  # Returns: array of symbols.  Essentially a constant array.
  def self.min_eol_note_fields()
    [:gen_desc, :diag_desc, :distribution, :habitat, :look_alikes, :uses]
  end

  def self.eol_note_fields()
    min_eol_note_fields
  end

  def self.all_note_fields()
    eol_note_fields.push(:notes)
  end

  # Creates RSS log as necessary.
  # Returns: nothing.
  def log(*args)
    self.rss_log ||= RssLog.new
    self.rss_log.add_with_date(*args)
  end

  # Creates RSS log as necessary.
  # Returns: nothing.
  def orphan_log(*args)
    self.rss_log ||= RssLog.new
    self.rss_log.orphan(self.display_name, *args)
  end

########################################

  RANKS_ABOVE_GENUS   = [:Family, :Order, :Class, :Phylum, :Kingdom]
  RANKS_BELOW_SPECIES = [:Form, :Variety, :Subspecies]
  RANKS_ABOVE_SPECIES = [:Genus] + RANKS_ABOVE_GENUS
  RANKS_BELOW_GENUS   = RANKS_BELOW_SPECIES + [:Species]
  ALL_RANKS =  RANKS_BELOW_GENUS + RANKS_ABOVE_SPECIES + [:Group]

  # Returns: array of symbols, from :Form to :Kingdom, then :Group.
  def self.all_ranks; ALL_RANKS; end

  # Returns: array of symbols, from :Family to :Kingdom.
  def self.ranks_above_genus; RANKS_ABOVE_GENUS; end

  # Returns: array of symbols, from :Form to :Species.
  def self.ranks_below_genus; RANKS_BELOW_GENUS; end

  # Returns: array of symbols, from :Genus to :Kingdom.
  def self.ranks_above_species; RANKS_ABOVE_SPECIES; end

  # Returns: array of symbols, from :Form to :Subspecies.
  def self.ranks_below_species; RANKS_BELOW_SPECIES; end

  # Is this name a family or higher?
  def above_genus?; RANKS_ABOVE_GENUS.include?(self.rank); end

  # Is this name a species or lower?
  def below_genus?; RANKS_BELOW_GENUS.include?(self.rank); end

  # Is this name a genus or higher?
  def above_species?; RANKS_ABOVE_SPECIES.include?(self.rank); end

  # Is this name a subspecies or lower?
  def below_species?; RANKS_BELOW_SPECIES.include?(self.rank); end

  # Returns: array of strings: "Unknown", "unknown", and "".
  def self.names_for_unknown()
    ['unknown', :app_unknown.l.downcase, '']
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

    # This removes the "sp" or "sp." in "Lactarius sp" and "Lactarius sp Author".
    in_str = in_str.strip
    if m = SP_PAT.match(in_str)
      in_str = m[1]
    elsif (m1 = AUTHOR_PAT.match(in_str)) and (m2 = SP_PAT.match(m1[1])) and (ABOVE_SPECIES_PAT.match(m2[1]))
      in_str = "#{m2[1]} #{m1[2]}"
    end

    name = in_str.strip
    if names_for_unknown.member? name.to_s.downcase
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
    else
      result = Name.find(:all, :conditions => ["#{deprecated_condition}(search_name = :name or text_name = :name)", {:name => name}])
      if (result == []) and (m = AUTHOR_PAT.match(name)) and ABOVE_SPECIES_PAT.match(m[1])
        name = m[1] + ' sp. ' + m[2]
        result = Name.find(:all, :conditions => ["#{deprecated_condition}(search_name = :name or text_name = :name)", {:name => name}])
      end
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
    result.review_status = :unreviewed
    result.ok_for_export = true
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
  # variety).  If there is ambiguity (due to different authors), then nil
  # is returned in that slot.  (Ancestors only go back to genus at the moment; I'm not sure
  # this will ever change for this routine, as it is purely mechanical.)
  # Note: check if any results are missing an id to determine which are new.
  # Returns: array of Name instances, NOT SAVED! (both new names and pre-
  #   existing names which could potentially have changes such as author)
  def self.names_from_string(in_str)
    result = []
    if names_for_unknown.member? in_str.to_s.downcase
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

  # Currently just parses the text name to find Genus and possible Species.
  # Ultimately this should get high level clades, but I don't have a good
  # source for that data yet. 
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

  # This one is similar, however it just returns a list of all taxa in the
  # rank above that contain this name.  Again, it only works for species or
  # lower for now.  It *can* return multiple names, if there are multiple
  # genera, for example, with the same name but different authors.
  def parents
    result = []
    if self.text_name.match(' ')
      name = self.text_name.sub(/( \S+\.)? \S+$/, '')
      result = Name.find(:all, :conditions => ['text_name = ?', name])
    end
    result
  end

########################################

  # Parse a string, return the following array:
  #  0: text_name         "Xx yy var. zz"         "Xx yy"         "Xx"
  #  1: display_name      "Xx yy var. zz Author"  "Xx yy Author"  "Xx sp. Author"
  #  2: observation_name  "Xx yy var. zz Author"  "Xx yy Author"  "Xx Author"
  #  3; search_name       "Xx yy var. zz Author"  "Xx yy Author"  "Xx sp. Author"
  #  4: parent_name
  #  5: rank              :Variety              :Species        :Genus
  #  6: author            "Author"              "Author"        "Author"
  def self.parse_name(str)
    (name, author) = parse_author(str)
    if parse = parse_group(name)
      rank = :Group
    elsif parse = parse_sp(name)
      rank = :Genus
    elsif parse = parse_species(name)
      rank = :Species
    elsif parse = parse_subspecies(name)
      rank = :Subspecies
    elsif parse = parse_variety(name)
      rank = :Variety
    elsif parse = parse_form(name)
      rank = :Form
    elsif parse = parse_above_species(name)
      rank = :Genus
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
      results = [
        match[1].gsub('ë', 'e'),
        format_string(match[1], deprecated),
        format_string(match[1] + ' sp.', deprecated),
        match[1].gsub('ë', 'e') + ' sp.',
        nil
      ]
    end
    results
  end

  # <Genus> sp. (or other higher rank)
  def self.parse_sp(in_str, deprecated=false)
    results = nil
    match = SP_PAT.match(in_str)
    if match
      results = [
        match[1].gsub('ë', 'e'),
        format_string(match[1], deprecated),
        format_string(match[1] + ' sp.', deprecated),
        match[1].gsub('ë', 'e') + ' sp.',
        nil
      ]
    end
    results
  end

  # <Genus> <species> (but reject <Genus> section -- unsupported right now)
  def self.parse_species(in_str, deprecated=false)
    results = nil
    match = SPECIES_PAT.match(in_str)
    if match and (match[2] != 'section')
      name = match[1] + ' ' + match[2]
      results = [
        name.gsub('ë', 'e'),
        format_string(name, deprecated),
        format_string(name, deprecated),
        name.gsub('ë', 'e'),
        match[1]
      ]
    end
    results
  end

  # <Genus> <species> subsp. <subspecies>
  def self.parse_subspecies(in_str, deprecated=false)
    results = nil
    match = SUBSPECIES_PAT.match(in_str)
    if match
      parent = match[1]
      child  = match[2]
      results = parse_species(parent, deprecated)
      results[0] += ' subsp. ' + child.gsub('ë', 'e')
      results[1] += ' subsp. ' + format_string(child, deprecated)
      results[2] += ' subsp. ' + format_string(child, deprecated)
      results[3] += ' subsp. ' + child.gsub('ë', 'e')
      results[4] = parent
    end
    results
  end

  # <Genus> <species> [subsp. <subspecies>] var. <variety>
  def self.parse_variety(in_str, deprecated=false)
    results = nil
    match = VARIETY_PAT.match(in_str)
    if match
      parent = match[1]
      child  = match[2]
      results = parse_subspecies(parent, deprecated) ||
                parse_species(parent, deprecated)
      results[0] += ' var. ' + child.gsub('ë', 'e')
      results[1] += ' var. ' + format_string(child, deprecated)
      results[2] += ' var. ' + format_string(child, deprecated)
      results[3] += ' var. ' + child.gsub('ë', 'e')
      results[4] = parent
    end
    results
  end

  # <Genus> <species> [subsp. <subspecies] [var. <subspecies>] f. <form>
  def self.parse_form(in_str, deprecated=false)
    results = nil
    match = FORM_PAT.match(in_str)
    if match
      parent = match[1]
      child  = match[2]
      results = parse_variety(parent, deprecated) ||
                parse_subspecies(parent, deprecated) ||
                parse_species(parent, deprecated)
      results[0] += ' f. ' + child.gsub('ë', 'e')
      results[1] += ' f. ' + format_string(child, deprecated)
      results[2] += ' f. ' + format_string(child, deprecated)
      results[3] += ' f. ' + child.gsub('ë', 'e')
      results[4] = parent
    end
    results
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
      raise :runtime_unrecognized_rank.t(:rank => rank)
    end
    if results.nil?
      raise :runtime_invalid_for_rank.t(:rank => rank, :name => name)
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
    dname = self.display_name.gsub(/\*\*([^*]+)\*\*/, '\1')
    oname = self.observation_name.gsub(/\*\*([^*]+)\*\*/, '\1')
    unless value
      # Add boldness
      dname.gsub!(/(__[^_]+__)/, '**\1**')
      if dname != oname
        oname.gsub!(/(__[^_]+__)/, '**\1**')
      end
    end
    self.display_name = dname
    self.observation_name = oname
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
        raise :runtime_unable_to_create_name.t(:name => parent_name)
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
      raise :runtime_invalid_name.t(:name => in_str)
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
        raise :runtime_name_already_used.t(:name => text_name)
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

  def reviewed_observations()
    Observation.find(:all, :conditions => "name_id = #{self.id} and vote_cache >= 2.4")
  end

  # Returns a hashtable contain all the notes
  def all_notes()
    result = {}
    for f in Name.all_note_fields
      result[f] = self.send(f)
    end
    result
  end

  def set_notes(notes)
    for f in Name.all_note_fields
      self.send("#{f}=", notes[f])
    end
  end

  def has_any_notes?()
    result = false
    for f in Name.all_note_fields
      field = self.send(f)
      result = field && (field != '')
      break if result
    end
    result
  end

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
  # Returns nothing.  DOES NOT SAVE!
  def prepend_notes(str)
    if !self.notes.nil? && self.notes != ""
      self.notes = str + "<br>\n\n" + self.notes
    else
      self.notes = str
    end
  end

  protected

  def validate # :nodoc:
    if !self.user
      errors.add(:user, :validate_name_user_missing.t)
    end

    if self.text_name.to_s.length > 100
      errors.add(:text_name, :validate_name_text_name_too_long.t)
    end
    if self.display_name.to_s.length > 200
      errors.add(:display_name, :validate_name_display_name_too_long.t)
    end
    if self.observation_name.to_s.length > 200
      errors.add(:observation_name, :validate_name_observation_name_too_long.t)
    end
    if self.search_name.to_s.length > 200
      errors.add(:search_name, :validate_name_search_name_too_long.t)
    end

    if self.author.to_s.length > 100
      errors.add(:author, :validate_name_author_too_long.t)
    end
    if self.citation.to_s.length > 200
      errors.add(:citation, :validate_name_citation_too_long.t)
    end
  end
end
