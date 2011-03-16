# encoding: utf-8
#
#  = Name Model
#
#  This model describes a single scientific name.  The related class Synonym,
#  which can own multiple Name's, more accurately embodies the abstract concept
#  of a species.  A Name, on the other hand, refers to a single epithet, in a
#  single sense -- that is, a unique combination of genus, species, and author.
#  (Name also embraces infraspecies and extrageneric taxa as well.)
#
#  == Name Formats
#
#    Method             Species              Genus                Kingdom
#   ----------------   ------------------   ------------------   --------------------
#    text_name          Xxx yyy              Xxx                  Fungi
#    search_name        Xxx yyy Author       Xxx sp. Author       Fungi sp.
#    display_name       __Xxx yyy__ Author   __Xxx__ Author       Kingdom of __Fungi__
#    observation_name   __Xxx yyy__ Author   __Xxx__ sp. Author   __Fungi__ sp.
#
#  == Regular Expressions
#
#  These are the sorts of things the regular expressions match:
#
#  ABOVE_SPECIES_PAT::  (Xxx)
#  SPECIES_PAT::        (Xxx) (yyy)
#  SUBSPECIES_PAT::     (Xxx yyy) subspecies|subsp|ssp|s. (yyy)
#  VARIETY_PAT::        (Species|Subspecies) variety|var|v. (yyy)
#  FORM_PAT::           (Species|Subspecies|Variety) forma|form|f. (yyy)
#  SP_PAT::             (Xxx) (species|sp.)
#  AUTHOR_PAT::         (Any-of-the-above) (Author...)
#  SENSU_PAT::          (Whatever...) (sensu Whatever...)
#  GROUP_PAT::          (Whatever...) (group|gr|gp.)
#  COMMENT_PAT::        (...) [(comment)]
#
#  * Results are grouped according to the parentheses shown above.
#  * Extra whitespace allowed on ends and in middle.
#  * Epithets ("Xxx" and "yyy" above) may contain any letters, including
#    "e" with umlaut, and embedded dashes.
#  * Specific epithets ("yyy" above) may be surrounded by double-quotes.
#  * Authors can be virtually anything: they start at the second uppercase
#    letter or any punctuation mark not allowed in the epithet patterns.
#  * "Whatever" is anything starting with an uppercase.
#  * Lastly, "comment" is anthing at all inside square brackets.
#
#  == Misspellings
#
#  As an intermediate solution, misspelled names should be synonymized with the
#  correct name, and the id of the correct Name placed in correct_spelling_id.
#  This has three results: the misspelled name is removed from auto-completion
#  lists and name_lister; show_name will include this in the "real" list of
#  Observation's instead of the "synonym" list.
#
#  == Classification
#
#  Taxonomic classification is currently a big hodgepodge of heuristics.  Taxa
#  at and below genus are handled by straight-forward parsing.  Taxa above
#  genus require a +classification+ string.  Taxa below genus should _not_ have
#  a +classification+ string (it is probably ignored?) _All_ taxa from genus
#  and up must have a +classification+ string if you want access to that
#  taxon's parents, and for taxa above genus, that taxon's children.  Note,
#  there is a lot of redundancy: even if a genus supplies its entire
#  classification, its parents must _also_ supply their entire classification.
#
#  *NOTE*: The classification string is sort of shared between the Name and
#  NameDescription instances.  It is structural, so it sort of belongs here,
#  however, at the same time, we want to allow draft descriptions to own a
#  copy.  Thus it is stored in both.  The one in Name is set whenever the
#  official NameDescription's copy changes.  Think of the one in Name as
#  caching the official version.
#
#  == Version
#
#  Changes are kept in the "names_versions" table using
#  ActiveRecord::Acts::Versioned.
#
#  == Attributes
#
#  id::               (-) Locally unique numerical id, starting at 1.
#  sync_id::          (-) Globally unique alphanumeric id, used to sync with remote servers.
#  created::          (-) Date/time it was first created.
#  modified::         (V) Date/time it was last modified.
#  user::             (V) User that created it.
#  version::          (V) Version number.
#  notes::            (V) Discussion of taxonomy.
#  ok_for_export::    (-) Mark names like "Candy canes" so they don't go to EOL.
#
#  ==== Definition of Taxon
#  rank::             (V) :Species, :Genus, :Order, etc.
#  text_name::        (V) "Xxx"
#  display_name::     (V) "Xxx sp. Author"
#  observation_name:: (V) "__Xxx__ Author"
#  search_name::      (V) "__Xxx__ sp. Author"
#  author::           (V) "Author"
#  citation::         (V) Citation where name was first published.
#  deprecated::       (V) Boolean: is this name deprecated?
#  synonym::          (-) Used to group synonyms.
#  correct_spelling:: (V) Name of correct spelling if misspelled.
#
#  ('V' indicates that this attribute is versioned in name_versions table.)
#
#  == Class methods
#
#  ==== Constants
#  unknown::                 "Unknown": instance of Name.
#  names_for_unknown::       "Unknown": accepted names in local language.
#  all_ranks::               Ranks: all
#  eol_ranks::               Ranks: in the order EOL wants them.
#  ranks_above_genus::       Ranks: above :Genus.
#  ranks_below_genus::       Ranks: below :Genus.
#  ranks_above_species::     Ranks: above :Species.
#  ranks_below_species::     Ranks: below :Species.
#  alt_ranks::               Ranks: map alternatives to our values.
#
#  ==== Classification
#  validate_classification:: Make sure +classification+ syntax is valid.
#  parse_classification::    Parse +classification+ string.
#
#  ==== Name Parsing
#  find_names::              Look up Names by text_name and search_name.
#  names_from_string::       Look up Name, create it, return it and parents.
#  parse_name::              Parse arbitrary taxon, return parts.
#  parse_by_rank::           Parse taxon of given rank, return parts.
#  parse_group::             Parse "Whatever group".
#  parse_sp::                Parse "Xxx sp.".
#  parse_species::           Parse "Xxx yyy".
#  parse_subspecies::        Parse "Xxx yyy subsp. zzz".
#  parse_variety::           Parse "Xxx yyy var. zzz".
#  parse_form::              Parse "Xxx yyy f. zzz".
#  parse_above_species::     Parse "Xxx".
#  parse_author::            Extract author from string.
#
#  ==== Other
#  primer::                  List of names used for priming auto-completer.
#  format_string::           Add itallics and/or boldness to string.
#
#  == Instance methods
#
#  ==== Formatting
#  text_name::               "Xxx"
#  format_name::             "Xxx sp. Author"
#  unique_text_name::        "Xxx (123)"
#  unique_format_name::      "Xxx sp. Author (123)"
#  change_text_name::        Change name, updating formats.
#  change_author::           Change author, updating formats.
#
#  ==== Taxonomy
#  above_genus?::            Is ranked above genus?
#  below_genus?::            Is ranked below genus?
#  above_species?::          Is ranked above species?
#  below_species?::          Is ranked below species?
#  is_lichen::               Is this a lichen or lichenicolous fungus?
#  all_parents::             Array of all parents.
#  parents::                 Array of immediate parents.
#  children::                Array of immediate children.
#  all_children::            Array of all children.
#  validate_classification:: Make sure +classification+ syntax is valid.
#  parse_classification::    Parse +classification+ string.
#  has_notes?::              Does it have notes discussing taxonomy?
#
#  ==== Synonymy
#  synonyms:                 List of all synonyms, including this Name.
#  synonym_ids:              List of all synonyms, including this Name, just ids.
#  sort_synonyms::           List of approved then deprecated synonyms.
#  approved_synonyms::       List of approved synonyms.
#  clear_synonym::           Remove this Name from its Synonym.
#  merge_synonyms::          Merge Synonym's of this and another Name.
#  transfer_synonym::        Transfer a Name from another Synonym into this Name's Synonym.
#  other_authors::           List of names that differ only in author.
#  other_author_ids::        List of names that differ only in author, just ids.
#
#  ==== Misspellings
#  is_misspelling?::         Is this name a misspelling?
#  correct_spelling::        Link to the correctly-spelled Name (or nil).
#  misspellings::            Names that call this their "correct spelling".
#  misspelling_ids::         Names that call this their "correct spelling", just ids.
#
#  ==== Status
#  deprecated::              Is this name deprecated?
#  status::                  Returns "Deprecated" or "Valid".
#  change_deprecated::       Changes deprecation status.
#  reviewed_observations::   (not used by anyone)
#
#  ==== Attachments
#  versions::                Old versions.
#  description::             Main NameDescription.
#  descriptions::            Alternate NameDescription's.
#  comments::                Comments on this Name.
#  interests::               Interests in this Name.
#  observations::            Observations using this Name as consensus.
#  namings::                 Namings that use this Name.
#  reviewed_observations::   Observation's that have > 80% confidence.
#
#  ==== Merging
#  mergable?::               Is it safe to merge this Name into another.
#  merge::                   Merge old name into this one and remove old one.
#
#  == Callbacks
#
#  create_description::      After create: create (empty) official NameDescription.
#  notify_users::            After save: notify interested User's of changes.
#
################################################################################

class Name < AbstractModel
  belongs_to :correct_spelling, :class_name => 'Name', :foreign_key => 'correct_spelling_id'
  belongs_to :description, :class_name => 'NameDescription' # (main one)
  belongs_to :rss_log
  belongs_to :synonym
  belongs_to :user

  has_many :descriptions, :class_name => 'NameDescription', :order => 'num_views DESC'
  has_many :comments,  :as => :target, :dependent => :destroy
  has_many :interests, :as => :target, :dependent => :destroy
  has_many :namings
  has_many :observations

  acts_as_versioned(
    :table_name => 'names_versions',
    :if_changed => [
      'rank',
      'text_name',
      'display_name',
      'observation_name',
      'search_name',
      'author',
      'citation',
      'deprecated',
      'correct_spelling',
      'notes',
  ])
  non_versioned_columns.push(
    'sync_id',
    'created',
    'num_views',
    'last_view',
    'ok_for_export',
    'rss_log_id',
    'synonym_id',
    'description_id',
    'classification' # (versioned in the default desc)
  )

  after_update :notify_users

  # Used by name/_form_name.rhtml
  attr_accessor :misspelling

  # Automatically (but silently) log creation and destruction.
  self.autolog_events = [:destroyed]

  # Callbacks whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id || 0
    if (ver.version != 1) and
       Name.connection.select_value(%(
         SELECT COUNT(*) FROM names_versions
         WHERE name_id = #{ver.name_id} AND user_id = #{ver.user_id}
       )).to_s == '0'
      SiteData.update_contribution(:add, :names_versions)
    end
  end

  # Get an Array of Observation's for this Name that have > 80% confidence.
  def reviewed_observations
    Observation.all(:conditions => "name_id = #{id} and vote_cache >= 2.4")
  end

  # Get list of common names to prime auto-completer.  Returns a simple Array
  # of up to 1000 name String's (no authors).
  #
  # *NOTE*: Since this is an expensive query (well, okay it only takes a tenth
  # of a second but that could change...), it gets cached periodically (daily?)
  # in a plain old file (NAME_PRIMER_CACHE_FILE).
  #
  def self.primer
    result = []
    if !File.exists?(NAME_PRIMER_CACHE_FILE) ||
       File.mtime(NAME_PRIMER_CACHE_FILE) < Time.now - 1.day

      # Get list of names sorted by how many times they've been used, then
      # re-sort by name.
      result = self.connection.select_values(%(
        SELECT names.text_name, COUNT(*) AS n
        FROM namings
        LEFT OUTER JOIN names ON names.id = namings.name_id
        WHERE correct_spelling_id IS NULL
        GROUP BY names.text_name
        ORDER BY n DESC
        LIMIT 1000
      )).uniq.sort

      open(NAME_PRIMER_CACHE_FILE, 'w').write(result.join("\n") + "\n")
    else
      result = open(USER_PRIMER_CACHE_FILE, "r:UTF-8").readlines.map(&:chomp)
    end
    return result
  end

  ################################################################################
  #
  #  :section: Formatting
  #
  ################################################################################

  # Alias for +display_name+ to be consistent with other objects.
  def format_name
    display_name
  end

  # Tack id on to end of +text_name+.
  def unique_text_name
    "#{text_name} (#{id})"
  end

  # Tack id on to end of +format_name+.
  def unique_format_name
    "#{display_name} (#{id})"
  end

  # Array of strings that mean "unknown" in the local language:
  #
  #   "unknown", ""
  #
  def self.names_for_unknown
    ['unknown', :unknown.l, '']
  end

  # Get an instance of the Name that means "unknown".
  def self.unknown
    Name.find(:first, :conditions => ['text_name = ?', 'Fungi'])
  end

  # Add itallics and (optionally) boldface to a String.  This is used
  # throughout this file and nowhere else.
  def self.format_string(str, deprecated=false)
    boldness = deprecated ? '' : '**'
    "#{boldness}__#{str}__#{boldness}"
  end

  ##############################################################################
  #
  #  :section: Taxonomy
  #
  ##############################################################################

  RANKS_ABOVE_GENUS   = [:Family, :Order, :Class, :Phylum, :Kingdom, :Domain]
  RANKS_BELOW_SPECIES = [:Form, :Variety, :Subspecies]
  RANKS_ABOVE_SPECIES = [:Genus] + RANKS_ABOVE_GENUS
  RANKS_BELOW_GENUS   = RANKS_BELOW_SPECIES + [:Species]
  ALL_RANKS =  RANKS_BELOW_GENUS + RANKS_ABOVE_SPECIES + [:Group]
  EOL_RANKS = [:Form, :Variety, :Subspecies, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom]
  ALT_RANKS = {:Division => :Phylum}

  # Returns an Array of Symbol's from :Form to :Domain, then :Group.
  def self.all_ranks
    ALL_RANKS
  end

  # Returns a Hash mapping alternative names to standard names (e.g.,
  # "Division" -> "Phylum").
  def self.alt_ranks
    ALT_RANKS
  end

  # Returns an Array of Symbol's from :Family to :Domain.
  def self.ranks_above_genus
    RANKS_ABOVE_GENUS
  end

  # Returns an Array of Symbol's from :Form to :Species.
  def self.ranks_below_genus
    RANKS_BELOW_GENUS
  end

  # Returns an Array of Symbol's from :Genus to :Domain.
  def self.ranks_above_species
    RANKS_ABOVE_SPECIES
  end

  # Returns an Array of Symbol's from :Form to :Subspecies.
  def self.ranks_below_species
    RANKS_BELOW_SPECIES
  end

  # Returns an Array of Symbol's from :Form to :Kingdom.
  def self.eol_ranks
    EOL_RANKS
  end

  # Is this Name a family or higher?
  def above_genus?
    RANKS_ABOVE_GENUS.include?(self.rank)
  end

  # Is this Name a species or lower?
  def below_genus?
    RANKS_BELOW_GENUS.include?(self.rank)
  end

  # Is this Name a genus or higher?
  def above_species?
    RANKS_ABOVE_SPECIES.include?(self.rank)
  end

  # Is this Name a subspecies or lower?
  def below_species?
    RANKS_BELOW_SPECIES.include?(self.rank)
  end

  # Is this Name in the "lichens" SpeciesList?  This is a temporary kludge
  # until RDF allows me to explicitly tag things as "lichenized".
  def is_lichen?
    # Check both this and genus, just in case I'm missing some species.
    ids = [id]
    if below_genus?
      genus = self.class.find_by_text_name(text_name.split.first)
      ids << genus.id if genus
    end
    ids = ids.map(&:to_s).join(',')

    (spl = SpeciesList.find_by_title('lichens')) and
    !!self.connection.select_value(%(
      SELECT names.id FROM observations_species_lists os
      JOIN observations o ON os.observation_id = o.id
      JOIN names ON names.id = o.name_id
      WHERE os.species_list_id = #{spl.id}
        AND o.name_id IN (#{ids})
    ))
  end

  # Returns an Array of all of this Name's ancestors, starting with its
  # immediate parent, running back to Eukarya.  It ignores misspellings.  It
  # chooses at random if there are more than one accepted parent taxa at a
  # given level.  (See comments for +parents+.)
  #
  #    child = Name.find_by_text_name('Letharia vulpina')
  #    for parent in child.all_parents
  #      puts parent.text_name
  #    end
  #
  #    # Produces:
  #    Letharia
  #    Parmeliaceae
  #    Lecanorales
  #    Ascomycotina
  #    Ascomycota
  #    Fungi
  #    Eukarya
  #
  def all_parents
    parents(:all)
  end

  # Returns an Array of all Name's under this one.  Ignores misspellings, but
  # includes deprecated Name's.  *NOTE*: This can be a _huge_ array!
  #
  #   parent = Name.find_by_text_name('Letharia')
  #   for child in parent.all_children
  #     puts child.text_name
  #   end
  #
  #   # Produces:
  #   'Letharia californica'
  #   'Letharia columbiana'
  #   'Letharia lupina'
  #   'Letharia vulpina'
  #   'Letharia vulpina f. californica'
  #
  def all_children
    children(:all)
  end

  # Returns an Array of all Name's in the rank above that contain this Name.
  # It _can_ return multiple names, if there are multiple genera, for example,
  # with the same name but different authors.  If any parent is approved, then
  # it only returns approved names.  It ignores misspellings.
  #
  #    child = Name.find_by_text_name('Letharia vulpina')
  #    for parent in child.parents
  #      puts parent.text_name
  #    end
  #
  #    # Produces:
  #    Letharia (First) Author
  #    Letharia (Another) One
  #
  def parents(all=false)
    results   = []
    lines     = nil
    next_rank = rank

    # Try ranks above ours one at a time until we find a parent.
    while all || results.empty?
      next_rank = ALL_RANKS[ALL_RANKS.index(next_rank) + 1]
      break if !next_rank || next_rank == :Group
      these = []

      # Once we go past genus we need to search the classification string.
      if RANKS_ABOVE_GENUS.include?(next_rank)

        if !lines
          # Check this name's classification first.
          str = classification
          if str.blank? && results.last
            # Next try the last genus's classification from subgeneric results.
            str = results.last.classification
          end
          if str.blank?
            # Finally try searching for any classification that includes this
            # name in it!
            str = Name.connection.select_value %(
              SELECT classification FROM names
              WHERE classification LIKE '%#{rank}: _#{text_name}%'
              LIMIT 1
            )
          end
          lines = parse_classification(str) rescue []
          break if lines.empty?
        end

        # Grab name for 'next_rank' from classification string.
        for line_rank, line_name in lines
          if line_rank == next_rank
            these += Name.find_all_by_text_name(line_name)
          end
        end

      # At and below genus, we do a database query on part of out name, e.g.,
      # if our name is "Xxx yyy var. zzz", we search first for species named
      # "Xxx yyy", then genera named "Xxx".)
      elsif next_rank == :Variety    && text_name.match(/^(.* var\. \S+)/)   ||
            next_rank == :Subspecies && text_name.match(/^(.* subsp\. \S+)/) ||
            next_rank == :Species    && text_name.match(/^(\S+ \S+)/)        ||
            next_rank == :Genus      && text_name.match(/^(\S+)/)
        these = Name.all(:conditions => "correct_spelling_id IS NULL
                                         AND rank = '#{next_rank}'
                                         AND text_name = '#{$1}'")
      end


      # Get rid of deprecated names unless all the results are deprecated.
      if !these.empty?
        unless these.select(&:deprecated).length == these.length
          these = these.reject(&:deprecated)
        end
        if all
          results << these.first
        else
          results = these
        end
      end
    end

    return results
  end

  # Returns an Array of Name's directly under this one.  Ignores misspellings,
  # but includes deprecated Name's.
  #
  #   parent = Name.find_by_text_name('Letharia')
  #   for child in parent.children
  #     puts child.text_name
  #   end
  #
  #   # Produces:
  #   'Letharia californica'
  #   'Letharia columbiana'
  #   'Letharia lupina'
  #   'Letharia vulpina'
  #
  #   parent = Name.find_by_text_name('Letharia vulpina')
  #   for child in parent.children
  #     puts child.text_name
  #   end
  #
  #   # Produces:
  #   'Letharia vulpina var. bogus'
  #   'Letharia vulpina f. californica'
  #
  #   # BUT NOT THIS!!
  #   'Letharia vulpina var. bogus f. foobar'
  #
  def children(all=false)
    results = []
    our_index = ALL_RANKS.index(rank)

    # If we're above genus we need to rely on classification strings.
    if RANKS_ABOVE_GENUS.include?(rank)

      # Querying every genus that refers to this ancestor could potentially get
      # expensive -- think of doing children for Eukarya!! -- but I'm not sure
      # how else to do it.  (There are currently 1927 genera in the database.)
      rows = Name.connection.select_rows %(
        SELECT classification, search_name FROM names
        WHERE rank = 'Genus'
          AND classification LIKE '%#{rank}: _#{text_name}_%'
      )

      # Genus should not be included in classifications.
      names = []
      if rank == :Family
        for cstr, sname in rows
          results += Name.find_all_by_search_name(sname)
        end

      # Grab all names below our rank.
      elsif all
        # Get set of ranks between ours and genus.
        accept_ranks = RANKS_ABOVE_GENUS.
                      reject {|x| ALL_RANKS.index(x) >= our_index}.map(&:to_s)
        # Search for names in each classification string.
        for cstr, sname in rows
          while cstr.sub!(/(\w+): _([^_]+)_\s*\Z/, '')
            line_rank, line_name = $1, $2
            # Grab names from end, one line at a time, until reach our rank
            # or a name we've already seen (assume all the higher names are
            # the same as what we saw before).
            if accept_ranks.include?(line_rank) &&
              !names.include?(line_name)
              names << line_name
            else
              break
            end
          end
          # (include genus, too)
          results += Name.find_all_by_search_name(sname)
        end

      # Grab all names at next lower rank.
      else
        next_rank = ALL_RANKS[our_index-1]
        match_str = "#{next_rank}: _"
        for cstr, sname in rows
          if (i = cstr.index(match_str)) and
             cstr[i..-1].match(/_([^_]+)_/)
            names << $1
          end
        end
      end

      # Convert these name strings into Names.
      results += names.uniq.map { |n| Name.find_all_by_text_name(n) }.flatten
      results.uniq!

      # Add subgeneric names for all genera in the results.
      if all
        results2 = []
        for name in results
          if name.rank == :Genus
            results2 += Name.all(:conditions =>
                                 "correct_spelling_id IS NULL
                                  AND text_name LIKE '#{name.text_name} %'")
          end
        end
        results += results2
      end

    # Get everything below our rank.
    else
      results = Name.all(:conditions => "correct_spelling_id IS NULL
                                         AND text_name LIKE '#{text_name} %'")

      # Remove subchildren if not getting all children.  This is trickier than
      # I originally expected because we want the children of G. species to
      # include the first two of these, but not the last:
      #   G. species var. variety            YES!!
      #   G. species f. form                 YES!!
      #   G. species var. variety f. form    NO!!
      if !all
        x = text_name.length
        results.reject! do |name|
          name.text_name[x..-1].match(/ .* .* /)
        end
      end
    end

    results
  end

  # Parse the given +classification+ String, validate it, and reformat it so
  # that it is standardized.  Return the reformatted String.  Throws a
  # RuntimeError if there are any errors.
  #
  # rank::  Ensure all Names are of higher rank than this.
  # text::  The +classification+ String.
  #
  # Example output:
  #
  #   Domain: _Eukarya_\r\n
  #   Kingdom: _Fungi_\r\n
  #   Phylum: _Basidiomycota_\r\n
  #   Class: _Basidomycotina_\r\n
  #   Order: _Agaricales_\r\n
  #   Family: _Agaricaceae_\r\n
  #
  def self.validate_classification(rank, text)
    result = text
    if text
      parsed_names = {}
      rank_index = Name.all_ranks.index(rank.to_sym)
      raise :runtime_user_bad_rank.t(:rank => rank) if rank_index.nil?

      # Check parsed output to make sure ranks are correct, names exist, etc.
      for (line_rank, line_name) in parse_classification(text)
        line_rank_index = Name.all_ranks.index(line_rank)
        raise :runtime_user_bad_rank.t(:rank => line_rank) if line_rank_index.nil?
        raise :runtime_invalid_rank.t(:line_rank => line_rank, :rank => rank) if line_rank_index <= rank_index
        raise :runtime_duplicate_rank.t(:rank => line_rank) if parsed_names[line_rank]
        parsed_names[line_rank] = line_name
      end

      # Reformat output, writing out lines in correct order.
      if parsed_names != {}
        result = ''
        for rank in Name.all_ranks.reverse
          if name = parsed_names[rank]
            result += "#{rank}: _#{name}_\r\n"
          end
        end
        result.strip!
      end
    end
    result
  end

  # Parse a +classification+ string.  Returns an Array of pairs of values.
  # Syntax is a bunch of lines of the form "rank: name":
  #
  #   Kingdom: Fungi
  #   Order: Agaricales
  #   Family: Agaricaceae
  #
  # It strips out excess whitespace.  Names can be surrounded by underscores.
  # It throws a RuntimeError if there are any syntax errors.
  #
  #   lines = Name.parse_classification(str)
  #   for (rank, name) in lines
  #     # rank = :Family
  #     # name = "Agaricaceae"
  #   end
  #
  def self.parse_classification(text)
    results = []
    if text
      alt_ranks = Name.alt_ranks
      for line in text.split(/\r?\n/)
        match = line.match(/^\s*([a-zA-Z]+):\s*_*([a-zA-Z]+)_*\s*$/)
        if match
          line_rank = match[1].downcase.capitalize.to_sym
          if alt_rank = alt_ranks[line_rank]
            line_rank = alt_rank
          end
          line_name = match[2]
          results.push([line_rank, line_name])
        elsif !line.blank?
          raise :runtime_invalid_classification.t(:text => line)
        end
      end
    end
    return results
  end

  # Pass off to class method of the same name.
  def validate_classification(str=nil)
    self.class.validate_classification(str || classification)
  end

  # Pass off to class method of the same name.
  def parse_classification(str=nil)
    self.class.parse_classification(str || classification)
  end

  # Does this Name have notes (presumably discussing taxonomy).
  def has_notes?
    notes and notes.match(/\S/)
  end

  ##############################################################################
  #
  #  :section: Synonymy
  #
  ##############################################################################

  # Returns "Deprecated" or "Valid" in the local language.
  def status
    deprecated ? :DEPRECATED.l : :ACCEPTED.l
  end

  # Same as synonyms, but returns ids.
  def synonym_ids
    @synonym_ids ||= begin
      if @synonyms
        @synonyms.map(&:id)
      elsif synonym_id
        Name.connection.select_values(%(
          SELECT id FROM names WHERE synonym_id = #{synonym_id}
        )).map(&:to_i)
      else
        [id]
      end
    end
  end

  # Returns an Array of all synonym Name's, including itself and misspellings.
  def synonyms
    @synonyms ||= begin
      if @synonym_ids
        # Slightly faster since id is primary index.
        Name.all(:conditions => ['id IN (?)', @synonym_ids])
      elsif synonym_id
        # Takes on average 0.050 seconds.
        Name.all(:conditions => "synonym_id = #{synonym_id}")

        # Involves instantiating a Synonym, something which need never happen.
        # synonym ? synonym.names : [self]
      else
        [self]
      end
    end
  end

  # Returns an Array of all _approved_ Synonym Name's, potentially including
  # itself.
  def approved_synonyms
    synonyms.reject(&:deprecated)
  end

  # Returns an Array of approved Synonym Name's and an Array of deprecated
  # Synonym Name's, including misspellings, but _NOT_ including itself.
  #
  #   approved_synonyms, deprecated_synonyms = name.sort_synonyms
  #
  def sort_synonyms
    all = synonyms - [self]
    accepted_synonyms   = all.reject(&:deprecated)
    deprecated_synonyms = all.select(&:deprecated)
  	[accepted_synonyms, deprecated_synonyms]
  end

  # Same as +other_authors+, but returns ids.
  def other_author_ids
    @other_author_ids ||= begin
      if @other_authors
        @other_authors.map(&:id)
      else
        Name.connection.select_values(%(
          SELECT id FROM names WHERE text_name = '#{text_name}'
        )).map(&:to_i)
      end
    end
  end

  # Returns an Array of Name's, including itself, which differ only in author.
  def other_authors
    @other_authors ||= begin
      if @other_author_ids
        # Slightly faster since id is primary index.
        Name.all(:conditions => ['id IN (?)', @other_author_ids])
      else
        Name.all(:conditions => ['text_name = ?', text_name])
      end
    end
  end

  # Removes this Name from its old Synonym.  It destroys the Synonym if there's
  # only one Name left in it afterword.  Returns nothing.  Any changes are
  # saved.
  #
  #   # If we have a group of three synonyms, say ids 1, 2 and 3:
  #   puts "before:   " + name.synonyms.map(&:id).join(', ')
  #   name1, name2, name3 = name.synonyms
  #   name1.clear_synonym
  #   puts "after 1:  " + name1.synonyms.map(&:id).join(', ')
  #   puts "after 2:  " + name2.synonyms.map(&:id).join(', ')
  #   puts "after 3:  " + name3.synonyms.map(&:id).join(', ')
  #
  #   # Produces:
  #   before:   1, 2, 3
  #   after 1:  1
  #   after 2:  2, 3
  #   after 3:  2, 3
  #
  def clear_synonym
    if synonym_id
      names = synonyms

      # Get rid of the synonym if only one going to be left in it.
      if names.length <= 2
        synonym.destroy
        for n in names
          n.synonym_id = nil
          n.save
        end

      # Otherwise, just dettach this name.
      else
        self.synonym_id = nil
        self.save
      end
    end
  end

  # Makes two Name's synonymous.  If either Name already has a Synonym, it will
  # merge the Synonym(s) into a single Synonym.  Returns nothing.  Any changes
  # are saved.
  #
  #   puts "before 1:  " + name1.synonyms.map(&:id).join(', ')
  #   puts "before 2:  " + name2.synonyms.map(&:id).join(', ')
  #   name1.merge_synonyms(name2)
  #   puts "after 1:   " + name1.synonyms.map(&:id).join(', ')
  #   puts "after 2:   " + name2.synonyms.map(&:id).join(', ')
  #
  #   # Produces:
  #   before 1:   1, 3
  #   before 2:   2
  #   after 1:  1, 2, 3
  #   after 2:  1, 2, 3
  #
  def merge_synonyms(name)

    # Other name has no synonyms, just transfer it over.
    if !name.synonym_id
      self.transfer_synonym(name)

    # *This* name has no synonyms, transfer us over to it.
    elsif !self.synonym_id
      name.transfer_synonym(self)

    # Both have synonyms -- merge them.
    # (Make sure they aren't already synonymized!)
    elsif self.synonym_id != name.synonym_id
      for n in name.synonyms
        self.transfer_synonym(n)
      end
    end
  end

  # Add Name to this Name's Synonym, but don't transfer that Name's synonyms.
  # Delete the other Name's old Synonym if there aren't any Name's in it
  # anymore.  Everything is saved.  (*NOTE*: Creates a new Synonym for this
  # Name if it doesn't already have one.)
  #
  #   correct_name.transfer_synonym(incorrect_name)
  #
  def transfer_synonym(name)
    # Make sure this name is attached to a synonym, creating one if necessary.
    if !self.synonym_id
      self.synonym = Synonym.create
      self.save
    end

    # Only transfer it over if it's not already a synonym!
    if self.synonym_id != name.synonym_id

      # Destroy old synonym if only one name left in it.
      if name.synonym and
         (name.synonym_ids.length <= 2)
        name.synonym.destroy
      end

      # Attach name to our synonym.
      name.synonym_id = self.synonym_id
      name.save
    end
  end

  ################################################################################
  #
  #  :section: Misspellings
  #
  ################################################################################

  # Is this Name misspelled?
  def is_misspelling?
    !!correct_spelling_id
  end

  # Same as +misspellings+, but returns ids.
  def misspelling_ids
    @misspelling_ids ||= begin
      if @misspellings
        @misspellings.map(&:id)
      else
        Name.connection.select_values(%(
          SELECT id FROM names WHERE correct_spelling_id = '#{id}'
        )).map(&:to_i)
      end
    end
  end

  # Array of Name's which are considered to be incorrect spellings of this one.
  def misspellings
    @misspellings ||= begin
      if @misspelling_ids
        # Slightly faster since id is primary index.
        Name.all(:conditions => ['id IN (?)', @misspelling_ids])
      else
        Name.all(:conditions => "correct_spelling_id = #{id}")
      end
    end
  end

  ################################################################################
  #
  #  :section: Merging
  #
  ################################################################################

  # Is it safe to merge this Name with another?  If any information will get
  # lost we return false.  In practice only if it has Namings.
  def mergable?
    namings.length == 0
  end

  # Merge all the stuff that refers to +old_name+ into +self+.  Usually, no
  # changes are made to +self+, however it might update the +classification+
  # cache if the old name had a better one -- NOT SAVED!!  Then +old_name+ is
  # destroyed; all the things that referred to +old_name+ are updated and
  # saved.
  def merge(old_name)
    xargs = {}

    # Move all observations over to the new name.
    for obs in old_name.observations
      obs.name = self
      obs.save
      Transaction.put_observation(
        :id   => obs,
        :name => self
      )
    end

    # Move all namings over to the new name.
    for name in old_name.namings
      name.name = self
      name.save
      Transaction.put_naming(
        :id   => name,
        :name => self
      )
    end

    # Move all misspellings over to the new name.
    for name in old_name.misspellings
      if name != self
        name.correct_spelling = self
        name.save
        Transaction.put_name(
          :id               => name,
          :correct_spelling => self
        )
      end
    end

    # Move over any interest in the old name.
    for int in Interest.find_all_by_target_type_and_target_id('Name',
                                                              old_name.id)
      int.target = self
      int.save
    end

    # Move over any notifications on the old name.
    for note in Notification.find_all_by_flavor_and_obj_id('name', old_name.id)
      note.obj_id = self.id
      note.save
    end

#     # Merge the two "main" descriptions if it can.
#     if self.description and old_name.description and
#        (self.description.source_type == :public) and
#        (old_name.description.source_type == :public)
#       self.description.merge(old_name.description, true)
#     end

    # If this one doesn't have a primary description and the other does,
    # then make it this one's.
    if !self.description && old_name.description
      self.description = old_name.description
    end

    # Update the classification cache if that changed in the process.
    if self.description &&
       (self.classification != self.description.classification)
      self.classification = self.description.classification
    end

    # Move over any remaining descriptions.
    for desc in old_name.descriptions
      xargs = {
        :id       => desc,
        :set_name => self,
      }
      desc.name_id = self.id
      desc.save
      Transaction.put_name_description(xargs)
    end

    # Log the action.
    old_name.log(:log_name_merged, :this => old_name.display_name,
                 :that => self.display_name)

    # Destroy past versions.
    editors = []
    for ver in old_name.versions
      editors << ver.user_id
      ver.destroy
    end

    # Update contributions for editors.
    editors.delete(old_name.user_id)
    for user_id in editors.uniq
      SiteData.update_contribution(:del, :names_versions, user_id)
    end

    # Save any notes the old name had.
    if old_name.has_notes?
      do_save if !changed?
      if has_notes?
        notes += "\n\nThese notes came from #{old_name.format_name} " +
                 "when it was merged with this name:\n\n"
        notes += old_name.notes
      else
        notes = old_name.notes
      end
      if do_save
        log(:log_name_updated, :touch => true)
        self.save
      end
    end

    # Finally destroy the name.
    old_name.destroy
    Transaction.delete_name(:id => old_name)
  end

  ##############################################################################
  #
  #  :section: Parsing Names
  #
  ##############################################################################

  ABOVE_SPECIES_PAT = /^\s* ("?[A-Z][a-zë\-]+"?) \s*$/x
  SP_PAT            = /^\s* ("?[A-Z][a-zë\-]+"?) \s+ (sp\.?|species) \s*$/x
  SPECIES_PAT       = /^\s* ("?[A-Z][a-zë\-]+"?) \s+ ([a-zë\-\"]+) \s*$/x
  SUBSPECIES_PAT    = /^\s* ("?[A-Z][a-zë\-]+"?  \s+  [a-zë\-\"]+)    \s+ (?:subspecies|subsp|ssp|s)\.? \s+ ([a-zë\-\"]+) \s*$/x
  VARIETY_PAT       = /^\s* ("?[A-Z][a-zë\-]+"?  \s+  [a-zë\-\"]+ (?: \s+ (?:subspecies|subsp|ssp|s)\.? \s+ [a-zë\-\"]+)?)    \s+ (?:variety|var|v)\.? \s+ ([a-zë\-\"]+) \s*$/x
  FORM_PAT          = /^\s* ("?[A-Z][a-zë\-]+"?  \s+  [a-zë\-\"]+ (?: \s+ (?:subspecies|subsp|ssp|s)\.? \s+ [a-zë\-\"]+)? (?: \s+ (?:variety|var|v)\.? \s+ [a-zë\-\"]+)?) \s+ (?:forma|form|f)\.? \s+ ([a-zë\-\"]+) \s*$/x
  AUTHOR_PAT        = /^\s* ("?[A-Z][a-zë\-\s\.\"]+?[a-zë\"](?:\s+sp\.)?) \s+ (("?[^a-z"\s]|in\s?ed\.?|auct\.?|van\sd[a-z]+\s[A-Z]).*) $/x   # (may have trailing space)
  SENSU_PAT         = /^\s* ("?[A-Z].*) \s+ (sens[u\.]\s+\S.*\S) \s*$/x
  GROUP_PAT         = /^\s* ("?[A-Z].*) \s+ (group|gr|gp)\.?     \s*$/x
  COMMENT_PAT       = /^\s* ([^\[\]]*)  \s+ \[(.*)\] \s*$/x

  # Parse a name given no additional information.  Returns an Array or nil:
  #
  #   0: text_name         "Xx yy var. zz"         "Xx yy"         "Xx"
  #   1: display_name      "Xx yy var. zz Author"  "Xx yy Author"  "Xx sp. Author"
  #   2: observation_name  "Xx yy var. zz Author"  "Xx yy Author"  "Xx Author"
  #   3; search_name       "Xx yy var. zz Author"  "Xx yy Author"  "Xx sp. Author"
  #   4: parent_name
  #   5: rank              :Variety                :Species        :Genus
  #   6: author            "Author"                "Author"        "Author"
  #
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

  # Parse a name given its rank.  Raises a RuntimeError if there are any
  # problems.  Used by +change_text_name+.  Returns an Array:
  #
  #   0: text_name
  #   1: display_name
  #   2: observation_name
  #   3; search_name
  #   4: parent_name
  #
  def self.parse_by_rank(in_str, in_rank, in_deprecated)
    results = nil
    rank = in_rank.to_sym
    if ranks_above_species.member?(rank)
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
      raise :runtime_unrecognized_rank.t(:rank => :"rank_#{rank.to_s.downcase}")
    end
    if !results
      raise :runtime_invalid_for_rank.t(:rank => :"rank_#{rank.to_s.downcase}",
                                        :name => in_str)
    end
    return results
  end

  # :stopdoc:
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
  # :startdoc:

  ##############################################################################
  #
  #  :section: Creating Names
  #
  ##############################################################################

  # Look up Name's with a given text_name or search_name.  By default tries to
  # weed out deprecated Name's, but if that results in an empty set, then it
  # returns the deprecated ones.  Both deprecated and non-deprecated Name's can
  # be returned by setting deprecated to true.
  #
  # Returns an Array of Name instances.
  #
  # in_str::        String to parse name from.
  # rank::          Tell it explicitly what the rank should be.
  # deprecated::    If true return both accepted _and_ deprecated Name's.
  #
  #   names = Name.find_names('Letharia vulpina')
  #
  # *NOTE*: This is an extraordinarily important method.  Whenever a User
  # enters a Name on this site, 99% of the time it ends up going through this
  # code at some point.
  #
  # *NOTE*: This can actually result in some Name's being changed.  In
  # particular, if the User ever tries to look up a Name that is missing the
  # author in our database, this method will insert the author the User gave
  # us, no questions asked.  It won't even inform anybody of this.  It just
  # magically happens.  This is the origin of some very bizarre behavior, so it
  # is worth bearing in mind.
  #
  def self.find_names(in_str, rank=nil, deprecated=false)
    in_str = in_str.to_s.strip_squeeze

    # Standardize "ssp", "var" and "f".
    in_str.sub!(/ (subsp|ssp)\.? /, ' subsp. ')
    in_str.sub!(/ (var|v)\.? /, ' var. ')
    in_str.sub!(/ (forma|f)\.? /, ' f. ')

    # This removes the "sp" or "sp." in "Lactarius sp" and "Lactarius sp Author".
    if m = SP_PAT.match(in_str)
      in_str = m[1]
    elsif (m1 = AUTHOR_PAT.match(in_str)) and (m2 = SP_PAT.match(m1[1])) and (ABOVE_SPECIES_PAT.match(m2[1]))
      in_str = "#{m2[1]} #{m1[2]}"
    end

    name = in_str.strip_squeeze # (again?!)
    if names_for_unknown.member?(name.downcase)
      name = "Fungi"
    end

    deprecated_condition = ''
    unless deprecated
      deprecated_condition = 'deprecated = 0 and '
    end

    # Look up the name.  Can get multiple matches if there are multiple names
    # with the same name but different authors.  (found via searching on
    # text_name).  However, if the user provides an explicit author, there
    # should be no way to get multiple matches.
    if rank
      result = Name.all(:conditions => [
        "#{deprecated_condition}rank = :rank AND
        (search_name = :name OR text_name = :name)",
        { :rank => rank, :name => name }
      ])

      if result.empty? and Name.ranks_above_species.member?(rank.to_sym)
        # I think this serves the purpose of allowing user to search on "Genus
        # Author", in which case (I believe) the desired matching name will
        # have text_name="Genus" and search_name="Genus sp. Author", neither
        # of which would match the above statement without the "sp." being
        # added. [-JPH 20080227]
        name.sub!(' ', ' sp. ')
        result = Name.all(:conditions => [
          "#{deprecated_condition}rank = :rank AND
          (search_name = :name OR text_name = :name)",
          { :rank => rank, :name => name }
        ])
      end

    else
      result = Name.all(:conditions => [
        "#{deprecated_condition}(search_name = :name OR text_name = :name)",
         { :name => name }
      ])

      if result.empty? and
         (m = AUTHOR_PAT.match(name)) and
         ABOVE_SPECIES_PAT.match(m[1])
        # (see comments above)
        name = m[1] + ' sp. ' + m[2]
        result = Name.all(:conditions => [
          "#{deprecated_condition}(search_name = :name OR text_name = :name)",
          { :name => name }
        ])
      end
    end

    if result.empty?

      # If provided a name complete with author, then check if that name exists
      # in the database without the author.
      name, author = Name.parse_author(in_str)

      if author
        # Don't check text_name because we don't want to match a name that has
        # a different author.  (Note that name already has the "sp." inserted
        # in the case of ranks above species.)
        if rank
          result = Name.all(:conditions => [
            "#{deprecated_condition}rank = :rank AND search_name = :name",
            { :rank => rank, :name => name }
          ])
        else
          result = Name.all(:conditions => [
            "#{deprecated_condition}search_name = :name",
            { :name => name }
          ])
        end

        # If we find it, add the author to it.  Probably should ask the user
        # for confirmation, but that looks really tricky.
        if result.length == 1
          result.first.change_author(author)
          result.first.save
        end
      end
    end

    # No names that aren't deprecated, so try for ones that are deprecated.
    if result.empty? and not deprecated
      result = find_names(in_str, rank, true)
    end
    result
  end

  # Parses a String, creates a Name for it and all its ancestors (if any don't
  # already exist), returns it in an Array (genus first, then species and
  # variety).  If there is ambiguity (due to different authors), then nil is
  # returned in that slot.  (Ancestors only go back to genus.)
  #
  # Returns an Array of Name instances, *UNSAVED*!!, with highest-level parents
  # coming first.  (Can contain both new and pre-existing Name's, any of which
  # could potentially have changes such as in the author.)
  #
  #   names = Name.names_from_string('Letharia vulpina (L.) Hue')
  #   # names = [
  #   #   Name: Letharia
  #   #   Name: Letharia vulpina (L.) Hue
  #   # ]
  #
  #   for name in names
  #     puts "new!" if name.new_record?
  #     save if name.changed?
  #   end
  #
  def self.names_from_string(in_str)
    result = []
    in_str = in_str.to_s.strip_squeeze

    # Check for unknown first.
    if names_for_unknown.member?(in_str.downcase)
      result << Name.unknown

    else
      # What is this all about??!! [-JPH 20100116]
      str = in_str.gsub(" near ", " ")

      if parse = parse_name(str)
        text_name, display_name, observation_name, search_name, parent_name,
          rank, author = parse

        # Fill in ancestors recursively first.
        if parent_name
          result = Name.names_from_string(parent_name)
        end

        # Look up name, trying to match author if supplied.
        matches = []
        name = text_name
        if author.blank?
          matches = Name.all(:conditions => ["text_name = ?", text_name])
        else
          matches = Name.all(:conditions => ["search_name = ?", search_name])
          if matches.empty?
            matches = Name.all(:conditions => ["text_name = ? AND
                                (author IS NULL OR author = '')", text_name])
          end
        end

        # If not found, create a new name.  (It's unsaved, don't worry!)
        if matches.empty?
          name = Name.make_name(rank, text_name,
                                :display_name => display_name,
                                :observation_name => observation_name,
                                :search_name => search_name,
                                :author => author)
          result << name

        # If found a unique match, take it.  Add author if one supplied.
        elsif matches.length == 1
          name = matches.first
          if name.author.blank? and !author.blank?
            name.change_author author
          end
          result << name

        # If ambiguous matches, fail.
        else
          result << nil
        end
      end
    end

    result
  end

  # Lookup a species by genus and species, creating it if necessary.  Returns a
  # Name instance, *UNSAVED*!!  (This is not used anywhere that I can see.)
  def self.make_species(genus, species, deprecated = false)
    Name.make_name :Species, sprintf('%s %s', genus, species), :display_name => format_string("#{genus} #{species}", deprecated)
  end

  # Lookup a genus, creating it if necessary.  Returns a Name instance,
  # *UNSAVED*!!  (This is not used anywhere that I can see.)
  def self.make_genus(text_name, deprecated = false)
    Name.make_name(:Genus, text_name,
                   :display_name => format_string(text_name, deprecated),
                   :observation_name => format_string("#{text_name} sp.", deprecated),
                   :search_name => text_name + ' sp.')
  end

  # Create a Name given all the various name formats, etc.
  # Used only by +make_name+.  (And +create_test_name+ in unit test.)
  # Returns a Name instance, *UNSAVED*!!
  def self.create_name(rank, text_name, author, display_name, observation_name, search_name)
    result = Name.new
    result.created          = now = Time.now
    result.modified         = now
    result.rank             = rank
    result.text_name        = text_name
    result.author           = author
    result.display_name     = display_name
    result.observation_name = observation_name
    result.search_name      = search_name
    result
  end

  # Look up a Name, creating it as necessary.  Requires +rank+ and +text_name+,
  # at least, supplying defaults for +search_name+, +display_name+, and
  # +observation_name+, and leaving +author+ blank by default.  Requires an
  # exact match of both +text_name+ and +author+. Returns:
  #
  # zero or one matches:: a Name instance, *UNSAVED*!!
  # multiple matches::    nil
  #
  # Used by +make_species+, +make_genus+, and +names_from_string+.
  #
  def self.make_name(rank, text_name, params)
    display_name = params[:display_name] || text_name
    observation_name = params[:observation_name] || display_name
    search_name = params[:search_name] || text_name
    author = params[:author]
    result = nil
    if rank
      matches = Name.find(:all, :conditions => ['search_name = ?', search_name])
      if matches == []
        result = Name.create_name(rank, text_name, author, display_name,
                                  observation_name, search_name)
      elsif matches.length == 1
        result = matches.first
      end
    end
    result
  end

  ################################################################################
  #
  #  :section: Changing Name
  #
  ################################################################################

  # Changes author.  Updates formatted names, as well.  *UNSAVED*!!
  #
  #   name.change_author('New Author')
  #   name.save
  #
  def change_author(new_author)
    old_author = self.author
    self.author = new_author
    self.display_name     = Name.replace_author(self.display_name,     old_author, new_author)
    self.observation_name = Name.replace_author(self.observation_name, old_author, new_author)
    self.search_name      = Name.replace_author(self.search_name,      old_author, new_author)
  end

  # Used by change_author().
  def self.replace_author(str, old_author, new_author) # :nodoc:
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

  # Changes deprecated status.  Updates formatted names, as well. *UNSAVED*!!
  #
  #   name.change_deprecated(true)
  #   name.save
  #
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
    if !value
      self.correct_spelling = nil
    end
    self.deprecated = value
  end

  # Changes the name, and creates parents as necessary.  Throws a RuntimeError
  # with the error message if unsuccessful in any way.  Returns nothing.
  #
  # *NOTE*: It does not save the changes to itself, but if it has to create or
  # update any parents (and caller has requested it), _those_ do get saved.
  #
  def change_text_name(in_str, new_author, new_rank, save_parents=false)

    # Clean up inputs.
    in_str     = in_str.to_s.strip_squeeze
    new_author = new_author.to_s.strip_squeeze

    self.class.common_errors(in_str)

    new_text_name, new_display_name, new_observation_name, new_search_name,
      parent_name = Name.parse_by_rank(in_str, new_rank, deprecated)

    # Make sure its parent(s) exist.
    if parent_name and not Name.find_by_text_name(parent_name)
      names = Name.names_from_string(parent_name)
      if names.last.nil?
        raise :runtime_unable_to_create_name.t(:name => parent_name)
      elsif save_parents
        # Make sure everything is saved.
        for n in names
          n.save
        end
      end
    end

    # What was this supposed to do??
    # Name.check_for_repeats(new_text_name, new_author)

    # Add author to all the appropriate name formats.
    if new_author
      new_display_name     = "%s %s" % [new_display_name, new_author]
      new_observation_name = "%s %s" % [new_observation_name, new_author]
      new_search_name      = "%s %s" % [new_search_name, new_author]
    end

    # Update everything.
    self.rank             = new_rank
    self.author           = new_author
    self.text_name        = new_text_name
    self.display_name     = new_display_name
    self.observation_name = new_observation_name
    self.search_name      = new_search_name
  end

  # Used by +change_text_name+.
  def self.common_errors(in_str) # :nodoc:
    result = true
    if /^[Uu]nknown|\sspecies$|\ssp.?\s*$|\ssensu\s/.match(in_str)
      raise :runtime_invalid_name.t(:name => in_str)
    end
  end

  # This was used by +change_text_name+, but apparently no longer.
  def self.check_for_repeats(text_name, author) # :nodoc:
    matches = []
    if !author.blank?
      matches = Name.all(:conditions => "text_name = '%s' and author = '%s'" % [text_name, author])
    else
      matches = Name.all(:conditions => "text_name = '%s'" % text_name)
    end
    for m in matches
      if m.id != self.id
        raise :runtime_name_already_used.t(:name => text_name)
      end
    end
  end

  ################################################################################
  #
  #  :section: Callbacks
  #
  ################################################################################

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users

    # "altered?" is acts_as_versioned's equivalent to Rails's changed? method.
    # It only returns true if *important* changes have been made.
    if altered?
      sender = User.current
      recipients = []

      # Tell admins of the change.
      for user_list in descriptions.map(&:admins)
        for user in user_list
          recipients.push(user) if user.email_names_admin
        end
      end

      # Tell authors of the change.
      for user_list in descriptions.map(&:authors)
        for user in user_list
          recipients.push(user) if user.email_names_author
        end
      end

      # Tell editors of the change.
      for user_list in descriptions.map(&:editors)
        for user in user_list
          recipients.push(user) if user.email_names_editor
        end
      end

      # Tell reviewers of the change.
      for user in descriptions.map(&:reviewer)
        recipients.push(user) if user && user.email_names_reviewer
      end

      # Tell masochists who want to know about all name changes.
      for user in User.find_all_by_email_names_all(true)
        recipients.push(user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in interests
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send notification to all except the person who triggered the change.
      for recipient in recipients.uniq - [sender]
        if recipient.created_here
          QueuedEmail::NameChange.create_email(sender, recipient, self, nil,
                                               false)
        end
      end
    end
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.user && !User.current
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
  end
end
