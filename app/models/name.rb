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
#    text_name          "Xantho" algoensis
#    real_text_name     "Xantho" algoënsis
#    search_name        "Xantho" algoensis Fries
#    real_search_name   "Xantho" algoënsis Fries
#    sort_name          Xantho" algoensis Fries
#    display_name       **__"Xantho" algoënsis__** Fries
#
#  == Regular Expressions
#
#  These are the sorts of things the regular expressions match:
#
#  GENUS_OR_UP_PAT::    (Xxx) sp? (Author)
#  SUBGENUS_PAT::       (Xxx subgenus yyy) (Author)
#  SECTION_PAT::        (Xxx ... sect. yyy) (Author)
#  SUBSECTION_PAT::     (Xxx ... subsect. yyy) (Author)
#  STIRPS_PAT::         (Xxx ... stirps yyy) (Author)
#  SPECIES_PAT::        (Xxx yyy) (Author)
#  SUBSPECIES_PAT::     (Xxx yyy ssp. zzz) (Author)
#  VARIETY_PAT::        (Xxx yyy ... var. zzz) (Author)
#  FORM_PAT::           (Xxx yyy ... f. zzz) (Author)
#  GROUP_PAT::          (Xxx yyy ...) group
#  AUTHOR_PAT:          (any of the above) (Author)
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
#  text_name::        (V) "Xantho" algoensis
#  real_text_name::   (V) "Xantho" algoënsis
#  search_name::      (V) "Xantho" algoensis Fries
#  real_search_name:: (V) "Xantho" algoënsis Fries
#  sort_name::        (V) Xantho" algoensis Fries
#  display_name::     (V) **__"Xantho" algoënsis__** Fries
#  author::           (V) Fries
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
#  find_or_create_name_and_parents:: Look up Name, create it, return it and parents.
#  parse_name::              Parse arbitrary taxon, return parts.
#  parse_author::            Grab the author from the end of a name.
#  parse_group::             Parse "Whatever group".
#  parse_genus_or_up::       Parse "Xxx".
#  parse_subgenus::          Parse "Xxx subgenus yyy".
#  parse_section::           Parse "Xxx sect. yyy".
#  parse_stirps::            Parse "Xxx stirps yyy".
#  parse_species::           Parse "Xxx yyy".
#  parse_subspecies::        Parse "Xxx yyy subsp. zzz".
#  parse_variety::           Parse "Xxx yyy var. zzz".
#  parse_form::              Parse "Xxx yyy f. zzz".
#
#  ==== Other
#  primer::                  List of names used for priming auto-completer.
#  format_name::             Add itallics and/or boldness to string.
#  clean_incoming_string::   Preprocess string from user before parsing.
#  standardize_name::        Standardize abbreviations in parsed name string.
#  standardize_author::      Standardize special abbreviations at start of parsed author.
#  squeeze_author::          Squeeze out space between initials, such as in "A. H. Smith".
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
#  at_or_below_genus?::      Is ranked at or below genus?
#  above_species?::          Is ranked above species?
#  below_species?::          Is ranked below species?
#  is_lichen::               Is this a lichen or lichenicolous fungus?
#  all_parents::             Array of all parents.
#  genus::                   Name of genus above this taxon (or nil).
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
#  mergeable?::               Is it safe to merge this Name into another.
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
      'search_name',
      'sort_name',
      'display_name',
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

  # (Destruction is already logged as a merge.)
  self.autolog_events = []

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

  def <=>(x)
    self.sort_name <=> x.sort_name
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
      result = open(NAME_PRIMER_CACHE_FILE, "r:UTF-8").readlines.map(&:chomp)
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
    "#{real_text_name} (#{id})"
  end

  # Tack id on to end of +format_name+.
  def unique_format_name
    "#{display_name} (#{id})"
  end

  def real_text_name
    Name.display_to_real_text(self)
  end

  def real_search_name
    Name.display_to_real_search(self)
  end

  def self.display_to_real_text(name)
    result = name.display_name.gsub(/\*?\*?__([^_]+)__\*?\*?/, '\1')
    return result[0..name.text_name.length-1]
  end

  def self.display_to_real_search(name)
    name.display_name.gsub(/\*?\*?__([^_]+)__\*?\*?/, '\1')
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
    Name.find_by_text_name('Fungi')
  end

  # Is this the "unknown" name?
  def unknown?
    self.text_name == 'Fungi'
  end

  def display_name
    str = self[:display_name]
    if User.current and
       User.current.hide_authors == :above_species and
       RANKS_ABOVE_SPECIES.include?(rank)
      str = str.sub(/^(\**__.*__\**).*/, '\\1')
    end
    return str
  end

  ##############################################################################
  #
  #  :section: Taxonomy
  #
  ##############################################################################

  RANKS_ABOVE_GENUS   = [:Family, :Order, :Class, :Phylum, :Kingdom, :Domain]
  RANKS_INSIDE_GENUS  = [:Stirps, :Subsection, :Section, :Subgenus]
  RANKS_BELOW_SPECIES = [:Form, :Variety, :Subspecies]
  RANKS_ABOVE_SPECIES = RANKS_INSIDE_GENUS + [:Genus] + RANKS_ABOVE_GENUS
  RANKS_BELOW_GENUS   = RANKS_BELOW_SPECIES + [:Species] + RANKS_INSIDE_GENUS
  ALL_RANKS = RANKS_BELOW_SPECIES + [:Species] +  RANKS_ABOVE_SPECIES + [:Group]
  EOL_RANKS = [:Form, :Variety, :Subspecies, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom] # Why doesn't this have :Species?
  EOL_RANKS_FOR_EXPORT = [:Form, :Variety, :Subspecies, :Species, :Genus]
  EOL_MIN_IMAGE_VOTE = 2
  EOL_MIN_OBSERVATION_VOTE = 2.4
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
    RANKS_ABOVE_GENUS.include?(rank)
  end

  # Is this Name a subgenus or lower?
  def below_genus?
    RANKS_BELOW_GENUS.include?(rank)
  end

  # Is this Name a genus or lower?
  def at_or_below_genus?
    RANKS_BELOW_GENUS.include?(rank) or rank == :Genus
  end

  # Is this Name a stirps or higher?
  def above_species?
    RANKS_ABOVE_SPECIES.include?(rank)
  end

  # Is this Name a subspecies or lower?
  def below_species?
    RANKS_BELOW_SPECIES.include?(rank)
  end

  def is_lichen?
    # Check both this and genus, just in case I'm missing some species.
    result = (Triple.find(:all, :conditions => ["subject = ':name/#{id}' and predicate = ':lichenAuthority'"]) != [])
    if !result and below_genus?
      genus = self.class.find_by_text_name(text_name.split.first)
      result = genus.is_lichen? if genus
    end
    result
  end

  def has_eol_data?
    if self.ok_for_export and not self.deprecated and EOL_RANKS_FOR_EXPORT.member?(self.rank)
      for o in self.observations
        if o.vote_cache and (o.vote_cache >= EOL_MIN_OBSERVATION_VOTE)
          for i in o.images
            if i.ok_for_export and i.vote_cache and (i.vote_cache >= EOL_MIN_IMAGE_VOTE)
              return true
            end
          end
        end
      end
      for d in self.descriptions
        if (d.review_status == :vetted) and d.ok_for_export and d.public
          return true
        end
      end
    end
    return false
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

  # Returns the Name of the genus above this taxon.  If there are multiple
  # matching genera, it chooses the first accepted one arbitrarily.  If this
  # name is at or above genus already, it returns nil.
  def genus
    result = nil
    if self.below_genus?
      genera = Name.find_all_by_text_name(self.text_name.split(' ').first)
      result = genera.reject(&:deprecated).first || genera.first
    end
    return result
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

      # At and below genus, we do a database query on part of our name, e.g.,
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

  def observation_count
    return observations.length
  end

  # Returns either self or name, whichever has more observations or was last used.
  def more_popular(name)
    result = self
    if not name.deprecated
      if self.deprecated
        result = name
      elsif self.observation_count < name.observation_count
        result = name
      elsif self.time_of_last_naming < name.time_of_last_naming
        result = name
      end
    end
    return result
  end

  # (if no namings, returns created)
  def time_of_last_naming
    @time_of_last_naming ||= begin
      last_use = Name.connection.select_value("SELECT MAX(created) FROM namings WHERE name_id = #{id}")
      last_use || created
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
  def mergeable?
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
      if name == self
        name.correct_spelling = nil
      else
        name.correct_spelling = self
      end
      name.save
      Transaction.put_name(
        :id                   => name,
        :set_correct_spelling => self
      )
    end

    # Move over any interest in the old name.
    for int in Interest.find_all_by_target_type_and_target_id('Name', old_name.id)
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

    # Fill in citation if new name is missing one.
    if citation.blank? and not old_name.citation.blank?
      self.citation = old_name.citation.strip_squeeze
    end

    # Save any notes the old name had.
    if old_name.has_notes? and (old_name.notes != self.notes)
      if has_notes?
        self.notes += "\n\nThese notes come from #{old_name.format_name} when it was merged with this name:\n\n" +
          old_name.notes
      else
        self.notes = old_name.notes
      end
      log(:log_name_updated, :touch => true)
      self.save
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

  SUBG_ABBR    = / subgenus | subg\.? /xi
  SECT_ABBR    = / section | sect\.? /xi
  SUBSECT_ABBR = / subsection | subsect\.? /xi
  STIRPS_ABBR  = / stirps /xi
  SP_ABBR      = / species | sp\.? /xi
  SSP_ABBR     = / subspecies | subsp\.? | ssp\.? | s\.? /xi
  VAR_ABBR     = / variety | var\.? | v\.? /xi
  F_ABBR       = / forma | form\.? | fo\.? | f\.? /xi
  GROUP_ABBR   = / group | gr\.? | gp\.? /xi
  AUCT_ABBR    = / auct\.? /xi
  INED_ABBR    = / in\s?ed\.? /xi
  NOM_ABBR     = / nomen | nom\.? /xi
  SENSU_ABBR   = / sensu?\.? /xi

  ANY_SUBG_ABBR   = / #{SUBG_ABBR} | #{SECT_ABBR} | #{SUBSECT_ABBR} | #{STIRPS_ABBR} /x
  ANY_SSP_ABBR    = / #{SSP_ABBR} | #{VAR_ABBR} | #{F_ABBR} /x
  ANY_NAME_ABBR   = / #{SUBG_ABBR} | #{SECT_ABBR} | #{SUBSECT_ABBR} | #{STIRPS_ABBR} | #{SP_ABBR} | #{SSP_ABBR} | #{VAR_ABBR} | #{F_ABBR} | #{GROUP_ABBR} /x
  ANY_AUTHOR_ABBR = / (?: #{AUCT_ABBR} | #{INED_ABBR} | #{NOM_ABBR} | #{SENSU_ABBR} ) (?:\s|$) /x

  UPPER_WORD = / [A-Z][a-zë\-]*[a-zë] | "[A-Z][a-zë\-\.]*[a-zë]" /x
  LOWER_WORD = / [a-z][a-zë\-]*[a-zë] | "[a-z][\wë\-\.]*[\wë]" /x
  LOWER_WORD_OR_SP_NOV = / (?!sp\s|sp$) #{LOWER_WORD} | sp\.\s\S*\d\S* /x

  # Matches the last epithet in a (standardized) name, including preceding abbreviation if there is one.
  LAST_PART = / (?: \s[a-z]+\.? )? \s \S+ $/x

  AUTHOR_START = / #{ANY_AUTHOR_ABBR} | van\s | de\s | [A-ZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞČŚŠ\(] | "[^a-z\s] /x

  AUTHOR_PAT      = /^ ("? #{UPPER_WORD} (?: \(? (?:\s #{ANY_SUBG_ABBR} \s #{UPPER_WORD})+ \)? | \s (?!#{AUTHOR_START}|#{ANY_SUBG_ABBR}) #{LOWER_WORD} (?:\s #{ANY_SSP_ABBR} \s #{LOWER_WORD})* | \s #{SP_ABBR} )? "?) (\s (?!#{ANY_NAME_ABBR}\s) #{AUTHOR_START}.*) $/x
  GENUS_OR_UP_PAT = /^ ("? #{UPPER_WORD} "?) (?: \s #{SP_ABBR} )? (\s #{AUTHOR_START}.*)? $/x
  SUBGENUS_PAT    = /^ ("? #{UPPER_WORD} \s \(? (?: #{SUBG_ABBR} \s #{UPPER_WORD}) \)? "?)  (\s #{AUTHOR_START}.*)? $/x
  SECTION_PAT     = /^ ("? #{UPPER_WORD} \s \(? (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)? (?: #{SECT_ABBR} \s #{UPPER_WORD}) \)? "?) (\s #{AUTHOR_START}.*)? $/x
  SUBSECTION_PAT  = /^ ("? #{UPPER_WORD} \s \(? (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)? (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)? (?: #{SUBSECT_ABBR} \s #{UPPER_WORD}) \)? "?) (\s #{AUTHOR_START}.*)? $/x
  STIRPS_PAT      = /^ ("? #{UPPER_WORD} \s \(? (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)? (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)? (?: #{SUBSECT_ABBR} \s #{UPPER_WORD} \s)? (?: #{STIRPS_ABBR} \s #{UPPER_WORD}) \)? "?) (\s #{AUTHOR_START}.*)? $/x
  SPECIES_PAT     = /^ ("? #{UPPER_WORD} \s #{LOWER_WORD_OR_SP_NOV} "?) (\s #{AUTHOR_START}.*)? $/x
  SUBSPECIES_PAT  = /^ ("? #{UPPER_WORD} \s #{LOWER_WORD} (?: \s #{SSP_ABBR} \s #{LOWER_WORD}) "?) (\s #{AUTHOR_START}.*)? $/x
  VARIETY_PAT     = /^ ("? #{UPPER_WORD} \s #{LOWER_WORD} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})? (?: \s #{VAR_ABBR} \s #{LOWER_WORD}) "?) (\s #{AUTHOR_START}.*)? $/x
  FORM_PAT        = /^ ("? #{UPPER_WORD} \s #{LOWER_WORD} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})? (?: \s #{VAR_ABBR} \s #{LOWER_WORD})? (?: \s #{F_ABBR} \s #{LOWER_WORD}) "?) (\s #{AUTHOR_START}.*)? $/x
  GROUP_PAT       = /^ ("? #{UPPER_WORD} (?: \s #{LOWER_WORD} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})? (?: \s #{VAR_ABBR} \s #{LOWER_WORD})? (?: \s #{F_ABBR} \s #{LOWER_WORD})? )? "?) \s #{GROUP_ABBR} $/x

  class ParsedName
    attr_accessor :text_name, :search_name, :sort_name, :display_name
    attr_accessor :rank, :author, :parent_name

    def initialize(params)
      @text_name = params[:text_name]
      @search_name = params[:search_name]
      @sort_name = params[:sort_name]
      @display_name = params[:display_name]
      @parent_name = params[:parent_name]
      @rank = params[:rank]
      @author = params[:author]
    end

    def real_text_name
      Name.display_to_real_text(self)
    end

    def real_search_name
      Name.display_to_real_search(self)
    end

    # Values required to create/modify attributes of Name instance.
    def params
      {
        :text_name => @text_name,
        :search_name => @search_name,
        :sort_name => @sort_name,
        :display_name => @display_name,
        :author => @author,
        :rank => @rank,
      }
    end
  end

  # Parse a name given no additional information.  Returns a ParsedName instance.
  def self.parse_name(str, rank=:Genus, deprecated=false)
    str = clean_incoming_string(str)
    parse_group(str, deprecated)       ||
    parse_subgenus(str, deprecated)    ||
    parse_section(str, deprecated)     ||
    parse_subsection(str, deprecated)  ||
    parse_stirps(str, deprecated)      ||
    parse_subspecies(str, deprecated)  ||
    parse_variety(str, deprecated)     ||
    parse_form(str, deprecated)        ||
    parse_species(str, deprecated)     ||
    parse_genus_or_up(str, deprecated, rank)
  end

  def self.parse_author(str)
    str = clean_incoming_string(str)
    results = [str, nil]
    if match = AUTHOR_PAT.match(str)
      results = [match[1].strip, match[2].strip]
    end
    results
  end

  def self.parse_group(str, deprecated=false)
    results = nil
    if match = GROUP_PAT.match(str)
      name = match[1]
      text_name = name.gsub('ë', 'e') + ' group'
      parent_name = name.sub(LAST_PART, '')
      results = ParsedName.new(
        :text_name    => text_name,
        :search_name  => text_name,
        :sort_name    => remove_first_quotes(text_name),
        :display_name => format_name(name, deprecated) + ' group',
        :parent_name  => parent_name,
        :rank         => :Group,
        :author       => ''
      )
    end
    results
  end

  def self.parse_genus_or_up(str, deprecated=false, rank=:Genus)
    results = nil
    if match = GENUS_OR_UP_PAT.match(str)
      name = match[1]
      author = standardize_author(match[2])
      author2 = author.blank? ? '' : ' ' + author
      text_name = name.gsub('ë', 'e')
      rank = :Genus unless RANKS_ABOVE_GENUS.include?(rank)
      results = ParsedName.new(
        :text_name    => text_name,
        :search_name  => text_name + author2,
        :sort_name    => remove_first_quotes(text_name + author2),
        :display_name => format_name(name, deprecated) + author2,
        :parent_name  => nil,
        :rank         => rank,
        :author       => author
      )
    end
    results
  end

  def self.parse_below_genus(str, deprecated, rank, pattern)
    results = nil
    if match = pattern.match(str)
      name, author = match[1], match[2].to_s
      name = standardize_sp_nov_variants(name) if rank == :Species
      (name, author, rank) = fix_default_variety_error(name, author, rank)
      name = standardize_name(name)
      author = standardize_author(author)
      author2 = author.blank? ? '' : ' ' + author
      text_name = name.gsub('ë', 'e')
      parent_name = name.sub(LAST_PART, '')
      results = ParsedName.new(
        :text_name    => text_name,
        :search_name  => text_name + author2,
        :sort_name    => remove_first_quotes(text_name + author2),
        :display_name => format_name(name, deprecated) + author2,
        :parent_name  => parent_name,
        :rank         => rank,
        :author       => author
      )
    end
    results
  end

  def self.parse_subgenus(str, deprecated=false)
    parse_below_genus(str, deprecated, :Subgenus, SUBGENUS_PAT)
  end

  def self.parse_section(str, deprecated=false)
    parse_below_genus(str, deprecated, :Section, SECTION_PAT)
  end

  def self.parse_subsection(str, deprecated=false)
    parse_below_genus(str, deprecated, :Subsection, SUBSECTION_PAT)
  end

  def self.parse_stirps(str, deprecated=false)
    parse_below_genus(str, deprecated, :Stirps, STIRPS_PAT)
  end

  def self.parse_species(str, deprecated=false)
    parse_below_genus(str, deprecated, :Species, SPECIES_PAT)
  end

  def self.parse_subspecies(str, deprecated=false)
    parse_below_genus(str, deprecated, :Subspecies, SUBSPECIES_PAT)
  end

  def self.parse_variety(str, deprecated=false)
    parse_below_genus(str, deprecated, :Variety, VARIETY_PAT)
  end

  def self.parse_form(str, deprecated=false)
    parse_below_genus(str, deprecated, :Form, FORM_PAT)
  end

  # Standardize various ways of writing sp. nov.  Convert to: Amanita "sp-T44"
  def self.standardize_sp_nov_variants(name)
    words = name.split(' ')
    if words.length > 2
      genus, epithet = words[0], words[2]
      epithet.sub!(/^"(.*)"$/, '\1')
      name = "#{genus} \"sp-#{epithet}\""
    else
      name.sub!(/ "sp\./i, ' "sp-')
    end
    return name
  end

  # Fix common error: Amanita vaginatae Author var. vaginatae
  # Convert to: Amanita vaginatae var. vaginatae Author
  def self.fix_default_variety_error(name, author, rank)
    if [:Species, :Subspecies, :Variety].include?(rank)
      last_word = name.split(' ').last
      if match = author.match(/^(.*) (#{ANY_SSP_ABBR}) (#{last_word})$/)
        name = "#{name} #{match[2]} #{match[3]}"
        author = match[1]
        rank = match[2].match(/^s/i) ? :Subspecies :
               match[2].match(/^v/i) ? :Variety : :Form
      end
    end
    return name, author, rank
  end

  def self.standardize_name(str)
    # remove old-style "(sect. Vaginatae)"
    str = str.sub(/ \((.*)\)$/, ' \\1')
    words = str.split(' ')
    # every other word, starting next-from-last, is an abbreviation
    i = words.length - 2
    while i > 0
      if words[i].match(/^f/i)
        words[i] = 'f.'
      elsif words[i].match(/^v/i)
        words[i] = 'var.'
      elsif words[i].match(/^sect/i)
        words[i] = 'sect.'
      elsif words[i].match(/^stirps/i)
        words[i] = 'stirps'
      elsif words[i].match(/^subg/i)
        words[i] = 'subgenus'
      elsif words[i].match(/^subsect/i)
        words[i] = 'subsect.'
      else
        words[i] = 'subsp.'
      end
      i -= 2
    end
    return words.join(' ')
  end

  def self.standardize_author(str)
    str = str.to_s.
      sub(/^#{AUCT_ABBR}/, 'auct. ').
      sub(/^#{INED_ABBR}/, 'ined. ').
      sub(/^#{NOM_ABBR}/, 'nom. ').
      sub(/^#{SENSU_ABBR}/, 'sensu ').
      strip_squeeze
    squeeze_author(str)
  end

  # Squeeze "A. H. Smith" into "A.H. Smith".
  def self.squeeze_author(str)
    str.gsub(/([A-Z]\.) (?=[A-Z]\.)/, '\\1')
  end

  # Add itallics and boldface to a standardized name (without author).
  def self.format_name(str, deprecated=false)
    boldness = deprecated ? '' : '**'
    words = str.split(' ')
    if (words.length & 1) == 0
      genus = words.shift
      words[0] = genus + ' ' + words[0]
    end
    i = words.length - 1
    while i >= 0
      words[i] = "#{boldness}__#{words[i]}__#{boldness}"
      i -= 2
    end
    return words.join(' ')
  end

  def self.clean_incoming_string(str)
    str.to_s.
        gsub(/“|”/,'"').   # let RedCloth format quotes
        gsub(/‘|’/,"'").
        gsub(/\u2028/,''). # line separator that we see occasionally
        strip_squeeze
  end

  # Adjust +search_name+ string to collate correctly.
  def self.remove_first_quotes(str)
    str.sub(/ "(sp[\-\.])/, ' {\1'). # Amanita "sp-1" goes at end of Amanita.
        gsub(/"([^"]*")/, '\1')      # Amanita "baccata" goes right after Amanita baccata.
  end

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
    results = []

    parse = parse_name(in_str)
    if parse
      text_name = parse.text_name
      search_name = parse.search_name
      author = parse.author

      if names_for_unknown.member?(name.downcase)
        name = 'Fungi'
      end

      conditions = []
      conditions_args = {}
      if not author.blank?
        conditions << 'search_name = :name'
        conditions_args[:name] = search_name
      else
        conditions << 'text_name = :name'
        conditions_args[:name] = text_name
      end
      unless deprecated
        conditions << 'deprecated = 0'
      end
      if rank
        conditions << 'rank = :rank'
        conditions_args[:rank] = rank
      end

      results = Name.all(:conditions => [ conditions.join(' AND '), conditions_args ])

      # If user provided author, check if name already exists without author.
      # If so, add author to that name automatically.
      if results.empty? and not author.blank?
        conditions_args[:name] = text_name
        results = Name.all(:conditions => [ conditions.join(' AND '), conditions_args ])
        # (this should never return more than one result)
        if results.length == 1
          results.first.change_author(author)
          results.first.save
        end
      end

      # No names that aren't deprecated, so try for ones that are deprecated.
      if results.empty? and not deprecated
        results = find_names(in_str, rank, true)
      end
    end

    return results
  end

  # Parses a String, creates a Name for it and all its ancestors (if any don't
  # already exist), returns it in an Array (genus first, then species, etc.  If
  # there is ambiguity (due to different authors), then +nil+ is returned in
  # the last slot.  Returns an Array of Name instances, *UNSAVED*!!
  #
  #   names = Name.find_or_create_name_and_parents('Letharia vulpina (L.) Hue')
  #   names.each(&:save)
  #
  def self.find_or_create_name_and_parents(in_str)
    result = []
    if parsed_name = parse_name(in_str)
      result = find_or_create_parsed_name_and_parents(parsed_name)
    end
    return result
  end

  def self.find_or_create_parsed_name_and_parents(parsed_name)
    result = []
    if names_for_unknown.member?(parsed_name.search_name.downcase)
      result << Name.unknown
    else
      if parsed_name.parent_name
        result = find_or_create_name_and_parents(parsed_name.parent_name)
      end
      result << find_or_create_parsed_name(parsed_name)
    end
    return result
  end

  def self.find_or_create_parsed_name(parsed_name)
    result = nil
    matches = find_matching_names(parsed_name)
    if matches.empty?
      result = Name.make_name(parsed_name.params)
    elsif matches.length == 1
      result = matches.first
      # Fill in author automatically if we can.
      if result.author.blank? and not parsed_name.author.blank?
        result.change_author(parsed_name.author)
      end
    else
      # Try to resolve ambiguity by taking the one with author.
      matches.reject! {|name| name.author.blank?}
      if matches.length == 1
        result = matches.first
      end
    end
    return result
  end

  def self.find_matching_names(parsed_name)
    result = []
    if parsed_name.author.blank?
      result = Name.all(:conditions => ['text_name = ?', parsed_name.text_name])
    else
      result = Name.all(:conditions => ['search_name = ?', parsed_name.search_name])
      if result.empty?
        result = Name.all(:conditions => ['text_name = ? AND author = ""', parsed_name.text_name])
      end
    end
    return result
  end

  # Look up a Name, creating it as necessary.  Requires +rank+ and +text_name+,
  # at least, supplying defaults for +search_name+, +display_name+, and
  # +sort_name+, and leaving +author+ blank by default.  Requires an
  # exact match of both +text_name+ and +author+. Returns:
  #
  # zero or one matches:: a Name instance, *UNSAVED*!!
  # multiple matches::    nil
  #
  # Used by +make_species+, +make_genus+, and +find_or_create_name_and_parents+.
  #
  def self.make_name(params)
    result = nil
    search_name = params[:search_name]
    matches = Name.find(:all, :conditions => ['search_name = ?', search_name])
    if matches.empty?
      result = Name.create_name(params)
    elsif matches.length == 1
      result = matches.first
    end
    result
  end

  # Create a Name given all the various name formats, etc.
  # Used only by +make_name+, and +create_test_name+ in unit test.
  # Returns a Name instance, *UNSAVED*!!
  def self.create_name(params)
    result = Name.new(params)
    result.created  = now = Time.now
    result.modified = now
    return result
  end

  ################################################################################
  #
  #  :section: Changing Name
  #
  ################################################################################

  # Changes the name, and creates parents as necessary.  Throws a RuntimeError
  # with error message if unsuccessful in any way.  Returns nothing. *UNSAVED*!!
  #
  # *NOTE*: It does not save the changes to itself, but if it has to create or
  # update any parents (and caller has requested it), _those_ do get saved.
  #
  def change_text_name(in_text_name, in_author, in_rank, save_parents=false)
    in_str = Name.clean_incoming_string("#{in_text_name} #{in_author}")
    parse = Name.parse_name(in_str, in_rank, deprecated)
    if not parse or parse.rank != in_rank
      raise :runtime_invalid_for_rank.t(:rank => :"rank_#{in_rank.to_s.downcase}", :name => in_str)
    end
    if parse.parent_name and
       not Name.find_by_text_name(parse.parent_name)
      parents = Name.find_or_create_name_and_parents(parse.parent_name)
      if parents.last.nil?
        raise :runtime_unable_to_create_name.t(:name => parse.parent_name)
      elsif save_parents
        for n in parents
          n.save
        end
      end
    end
    self.attributes = parse.params
  end

  # Changes author.  Updates formatted names, as well.  *UNSAVED*!!
  #
  #   name.change_author('New Author')
  #   name.save
  #
  def change_author(new_author)
    old_author = self.author
    self.author = new_author.to_s
    self.search_name  = replace_author(search_name,  old_author, new_author)
    self.sort_name    = replace_author(sort_name,    old_author, new_author)
    self.display_name = replace_author(display_name, old_author, new_author)
  end

  # Used by change_author().
  def replace_author(str, old_author, new_author) # :nodoc:
    result = str.strip
    unless old_author.blank?
      ri = result.rindex(' ' + old_author)
      if ri and (ri + old_author.length + 1 == result.length)
        result = result[0..ri].strip
      end
    end
    unless new_author.blank?
      result += ' ' + new_author
    end
    return result
  end

  # Changes deprecated status.  Updates formatted names, as well. *UNSAVED*!!
  #
  #   name.change_deprecated(true)
  #   name.save
  #
  def change_deprecated(deprecated)
    # remove existing boldness
    name = display_name.gsub(/\*\*([^*]+)\*\*/, '\1')
    if not deprecated
      # add new boldness
      name.gsub!(/(__[^_]+__)/, '**\1**')
      self.correct_spelling = nil
    end
    self.display_name = name
    self.deprecated = deprecated
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
          QueuedEmail::NameChange.create_email(sender, recipient, self, nil, false)
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

    if self.text_name.to_s.binary_length > 100
      errors.add(:text_name, :validate_name_text_name_too_long.t)
    end
    if self.search_name.to_s.binary_length > 200
      errors.add(:search_name, :validate_name_search_name_too_long.t)
    end
    if self.sort_name.to_s.binary_length > 200
      errors.add(:sort_name, :validate_name_sort_name_too_long.t)
    end
    if self.display_name.to_s.binary_length > 200
      errors.add(:display_name, :validate_name_display_name_too_long.t)
    end

    if self.author.to_s.binary_length > 100
      errors.add(:author, :validate_name_author_too_long.t)
    end
  end
end
