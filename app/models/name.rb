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
#    text_name          "Xanthoparmelia" coloradoensis
#    (real_text_name)   "Xanthoparmelia" coloradoënsis
#                         (derived on the fly from display_name)
#    search_name        "Xanthoparmelia" coloradoensis Fries
#    (real_search_name) "Xanthoparmelia" coloradoënsis Fries
#                         (derived on the fly from display_name)
#    sort_name          Xanthoparmelia" coloradoensis Fries
#    display_name       **__"Xanthoparmelia" coloradoënsis__** Fries
#    observation_name   **__"Xanthoparmelia" coloradoënsis__** Fries
#                         (adds "sp." on the fly for genera)
#
#    text_name          Amanita muscaria var. muscaria
#                         (pure text, no accents or authors)
#    (real_text_name)   Amanita muscaria var. muscaria
#                         (minus authors, but with umlauts if exist)
#    search_name        Amanita muscaria var. muscaria (L.) Lam.
#                         (what one would typically search for)
#    (real_search_name) Amanita muscaria (L.) Lam. var. muscaria
#                         (parsing this should result in identical name)
#    sort_name          Amanita muscaria  {6var.  !muscaria  (L.) Lam.
#                         (nonsense string which sorts name in correct place)
#    display_name       **__Amanita muscaria__** (L.) Lam. var. **__muscaria__**
#                         (formatted as for publication)
#    observation_name   **__Amanita muscaria__** (L.) Lam. var. **__muscaria__**
#                         (formatted as for publication)
#
#  Note about "real" text_name and search_name: These are required by edit
#  forms.  If the user inputs a name with an accent (ë is the only one
#  allowed), but there is an error or warning that requires the user to
#  resubmit the form, we need to be able to fill the field in with the correct
#  name *including* the umlaut.  That is, if you re-parse real_search_name, it
#  must result in the identical Name object.  This is not true of search_name,
#  because it will lose the umlaut.
#
#  == Regular Expressions
#
#  These are the sorts of things the regular expressions match:
#
#  GENUS_OR_UP_PAT::  (Xxx) sp? (Author)
#  SUBGENUS_PAT::     (Xxx subgenus yyy) (Author)
#  SECTION_PAT::      (Xxx ... sect. yyy) (Author)
#  SUBSECTION_PAT:    (Xxx ... subsect. yyy) (Author)
#  STIRPS_PAT::       (Xxx ... stirps yyy) (Author)
#  SPECIES_PAT:       (Xxx yyy) (Author)
#  SUBSPECIES_PAT::   (Xxx yyy ssp. zzz) (Author)
#  VARIETY_PAT::      (Xxx yyy ... var. zzz) (Author)
#  FORM_PAT::         (Xxx yyy ... f. zzz) (Author)
#  GROUP_PAT::        (Xxx yyy ...) group or clade
#  AUTHOR_PAT:        (any of the above) (Author)
#
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
#  created_at::       (-) Date/time it was first created.
#  updated_at::       (V) Date/time it was last updated.
#  user::             (V) User that created it.
#  version::          (V) Version number.
#  notes::            (V) Discussion of taxonomy.
#  ok_for_export::    (-) Mark names like "Candy canes" so they don't go to EOL.
#
#  ==== Definition of Taxon
#  rank::             (V) :Species, :Genus, :Order, etc.
#  text_name::        (V) "Xanthoparmelia" coloradoensis
#  real_text_name::   (V) "Xanthoparmelia" coloradoënsis
#  search_name::      (V) "Xanthoparmelia" coloradoensis Fries
#  real_search_name:: (V) "Xanthoparmelia" coloradoënsis Fries
#  sort_name::        (V) Xanthoparmelia" coloradoensis Fries
#  display_name::     (V) **__"Xanthoparmelia" coloradoënsis__** Fries
#  observation_name:: (V) **__"Xanthoparmelia" coloradoënsis__** Fries
#                         (adds "sp." on the fly for genera)
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
#  find_names::              Parses string, looks up Name by search_name,
#                              falls back on text_name.
#  find_names_filling_in_authors:: Look up Name's by text_name and search_name;
#                              fills in authors if supplied.
#  find_or_create_name_and_parents:: Look up Name, create it,
#                              return it and parents.
#  extant_match_to_parsed_name :: 1st existing Name matching ParsedName
#  new_name_from_parsed_name:: Make new Name instance from a ParsedName
#  parse_name::               Parse arbitrary taxon, return parts.
#  parse_author::             Grab the author from the end of a name.
#  parse_group::              Parse "Whatever group" or "whatever clade".
#  parse_genus_or_up::        Parse "Xxx".
#  parse_subgenus::           Parse "Xxx subgenus yyy".
#  parse_section::            Parse "Xxx sect. yyy".
#  parse_stirps::             Parse "Xxx stirps yyy".
#  parse_species::            Parse "Xxx yyy".
#  parse_subspecies::         Parse "Xxx yyy subsp. zzz".
#  parse_variety::            Parse "Xxx yyy var. zzz".
#  parse_form::               Parse "Xxx yyy f. zzz".
#
#  ==== Other
#  primer::                  List of names used for priming auto-completer.
#  format_name::             Add itallics and/or boldness to string.
#  clean_incoming_string::   Preprocess string from user before parsing.
#  standardize_name::        Standardize abbreviations in parsed name string.
#  standardize_author::      Standardize special abbreviations
#                              at start of parsed author.
#  squeeze_author::          Squeeze out space between initials,
#                              such as in "A. H. Smith".
#  ==== Limits
#  author_limit::            Max # of characters for author
#  display_name_limit::      Max # of characters for display_name
#  search_name_limit::       Max # of characters for search_name
#  sort_name_limit::         Max # of characters for sort_name
#  text_name_limit::         Max # of characters for text_name
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
#  below_genus?::            Is ranked below genus?
#  at_or_below_genus?::      Is ranked at or below genus?
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
#  synonym_ids:              List of IDs of all synonyms, including this Name
#  sort_synonyms::           List of approved then deprecated synonyms.
#  approved_synonyms::       List of approved synonyms.
#  clear_synonym::           Remove this Name from its Synonym.
#  merge_synonyms::          Merge Synonym's of this and another Name.
#  transfer_synonym::        Transfer a Name from another Synonym
#                              into this Name's Synonym.
#  other_authors::           List of names that differ only in author.
#  other_author_ids::        List of ids of names that differ only in author
#
#  ==== Misspellings
#  is_misspelling?::         Is this name a misspelling?
#  correct_spelling::        Link to the correctly-spelled Name (or nil).
#  misspellings::            Names that call this their "correct spelling".
#  misspelling_ids::         Names that call this their "correct spelling",
#                              just ids.
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
#  mergeable?::              Is it safe to merge this Name into another?
#  merge::                   Merge old name into this one and remove old one.
#
#  == Callbacks
#
#  create_description::      After create: create (empty) official
#                              NameDescription.
#  notify_users::            After save: notify interested User's of changes.
#
################################################################################
#
class Name < AbstractModel
  require "acts_as_versioned"
  require "fileutils"

  # enum definitions for use by simple_enum gem
  # Do not change the integer associated with a value
  as_enum(:rank,
          {
            Form: 1,
            Variety: 2,
            Subspecies: 3,
            Species: 4,
            Stirps: 5,
            Subsection: 6,
            Section: 7,
            Subgenus: 8,
            Genus: 9,
            Family: 10,
            Order: 11,
            Class: 12,
            Phylum: 13,
            Kingdom: 14,
            Domain: 15,
            Group: 16 # used for both "group" and "clade"
          },
          source: :rank,
          accessor: :whiny)

  belongs_to :correct_spelling, class_name: "Name",
                                foreign_key: "correct_spelling_id"
  belongs_to :description, class_name: "NameDescription" # (main one)
  belongs_to :rss_log
  belongs_to :synonym
  belongs_to :user

  has_many :descriptions, -> { order "num_views DESC" },
           class_name: "NameDescription"
  has_many :comments,  as: :target, dependent: :destroy
  has_many :interests, as: :target, dependent: :destroy
  has_many :namings
  has_many :observations

  acts_as_versioned(
    table_name: "names_versions",
    if_changed: %w[
      rank
      text_name
      search_name
      sort_name
      display_name
      author
      citation
      deprecated
      correct_spelling
      notes
      lifeform
    ]
  )
  non_versioned_columns.push(
    "created_at",
    "updated_at",
    "num_views",
    "last_view",
    "ok_for_export",
    "rss_log_id",
    # "accepted_name_id",
    "synonym_id",
    "description_id",
    "classification", # (versioned in the default desc)
    "locked"
  )

  before_create :inherit_stuff
  before_update :update_observation_cache
  after_update :notify_users

  # Notify webmaster that a new name was created.
  after_create do |name|
    user    = User.current || User.admin
    subject = "#{user.login} created #{name.real_text_name}"
    content = "#{MO.http_domain}/name/show_name/#{name.id}"
    WebmasterEmail.build(user.email, content, subject)
  end

  # Used by name/_form_name.rhtml
  attr_accessor :misspelling

  # (Destruction is already logged as a merge.)
  self.autolog_events = []

  # Callbacks whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id || 0
    if (ver.version != 1) &&
       Name.connection.select_value(%(
         SELECT COUNT(*) FROM names_versions
         WHERE name_id = #{ver.name_id} AND user_id = #{ver.user_id}
       )).to_s == "0"
      SiteData.update_contribution(:add, :names_versions)
    end
  end

  def <=>(x)
    sort_name <=> x.sort_name
  end

  def best_brief_description
    if description
      if description.gen_desc.blank?
        description.diag_desc
      else
        description.gen_desc
      end
    end
  end

  # Get an Array of Observation's for this Name that have > 80% confidence.
  def reviewed_observations
    Observation.where("name_id = #{id} AND vote_cache >= 2.4").to_a
  end

  # Get list of common names to prime auto-completer.  Returns a simple Array
  # of up to 1000 name String's (no authors).
  #
  # *NOTE*: Since this is an expensive query (well, okay it only takes a tenth
  # of a second but that could change...), it gets cached periodically (daily?)
  # in a plain old file (MO.name_primer_cache_file).
  #
  def self.primer
    result = []
    if !File.exist?(MO.name_primer_cache_file) ||
       File.mtime(MO.name_primer_cache_file) < Time.now - 1.day

      # Get list of names sorted by how many times they've been used, then
      # re-sort by name.
      result = connection.select_values(%(
        SELECT names.text_name, COUNT(*) AS n
        FROM namings
        LEFT OUTER JOIN names ON names.id = namings.name_id
        WHERE correct_spelling_id IS NULL
        GROUP BY names.text_name
        ORDER BY n DESC
        LIMIT 1000
      )).uniq.sort

      FileUtils.mkdir_p(File.dirname(MO.name_primer_cache_file))
      file = File.open(MO.name_primer_cache_file, "w:utf-8")
      file.write(result.join("\n") + "\n")
      file.close
    else
      file = File.open(MO.name_primer_cache_file, "r:UTF-8")
      result = file.readlines.map(&:chomp)
      file.close
    end
    result
  end

  # Used by show_name.
  def self.count_observations(names)
    ids = names.map(&:id)
    counts_and_ids = Name.connection.select_rows(%(
        SELECT count(*) c, names.id i FROM observations, names
        WHERE observations.name_id = names.id
        AND names.id IN (#{ids.join(", ")}) group by names.id
    ))
    result = {}
    counts_and_ids.each { |row| result[row[1]] = row[0] }
    result
  end

  ##############################################################################
  #
  #  :section: Formatting
  #
  ##############################################################################

  # Alias for +display_name+ to be consistent with other objects.
  def format_name
    display_name
  end

  # Tack id on to end of +text_name+.
  def unique_text_name
    real_text_name + " (#{id || "?"})"
  end

  # Tack id on to end of +format_name+.
  def unique_format_name
    display_name + " (#{id || "?"})"
  end

  # (This gives us the ability to format names slightly differently when
  # applied to observations.  For example, we might tack on "sp." to some
  # higher-ranked taxa here.)
  def observation_name
    display_name
  end

  def real_text_name
    Name.display_to_real_text(self)
  end

  def real_search_name
    Name.display_to_real_search(self)
  end

  def self.display_to_real_text(name)
    name.display_name.gsub(/ ^\*?\*?__ | __\*?\*?[^_\*]*$ /x, "").
      gsub(/__\*?\*? [^_\*]* \s (#{ANY_NAME_ABBR}) \s \*?\*?__/x, ' \1 ').
      gsub(/__\*?\*? [^_\*]* \*?\*?__/x, " "). # (this part should be unnecessary)
      # Because "group" was removed by the 1st gsub above,
      # tack it back on (if it was part of display_name)
      concat(group_suffix(name))
  end

  def self.group_suffix(name)
    GROUP_CHUNK.match(name.display_name).to_s
  end

  def self.display_to_real_search(name)
    name.display_name.gsub(/\*?\*?__([^_]+)__\*?\*?/, '\1')
  end

  # Array of strings that mean "unknown" in the local language:
  #
  #   "unknown", ""
  #
  def self.names_for_unknown
    ["unknown", :unknown.l, ""]
  end

  # Get an instance of the Name that means "unknown".
  def self.unknown
    Name.find_by_text_name("Fungi")
  end

  # Is this the "unknown" name?
  def unknown?
    text_name == "Fungi"
  end

  def known?
    !unknown?
  end

  def imageless?
    text_name == "Imageless"
  end

  def display_name
    str = self[:display_name]
    if User.current &&
       User.current.hide_authors == :above_species &&
       Name.ranks_above_species.include?(rank)
      str = str.sub(/^(\**__.*__\**).*/, '\\1')
    end
    str
  end

  # Info to include about each name in merge requests.
  def merge_info
    num_obs     = observations.count
    num_namings = namings.count
    "#{:NAME.l} ##{id}: #{real_search_name} [o=#{num_obs}, n=#{num_namings}]"
  end

  # Make sure display names are in boldface for accepted names, and not in
  # boldface for deprecated names.
  def self.make_sure_names_are_bolded_correctly
    msgs = Name.connection.select_values(%(
      SELECT id FROM names
      WHERE IF(deprecated, display_name LIKE "%*%", display_name NOT LIKE "%*%")
    )).map do |id|
      name = Name.find(id)
      name.change_deprecated(name.deprecated)
      name.save
      "The name #{name.search_name.inspect} " \
      "should #{name.deprecated && 'not '} have been in boldface."
    end
  end

  ##############################################################################
  #
  #  :section: Taxonomy
  #
  ##############################################################################

  # Returns a Hash mapping alternative ranks to standard ranks (all Symbol's).
  def self.alt_ranks
    { Division: :Phylum }
  end

  def self.all_ranks
    [:Form, :Variety, :Subspecies, :Species,
     :Stirps, :Subsection, :Section, :Subgenus, :Genus,
     :Family, :Order, :Class, :Phylum, :Kingdom, :Domain,
     :Group]
  end

  def self.ranks_above_genus
    [:Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group]
  end

  def self.ranks_between_kingdom_and_genus
    [:Phylum, :Subphylum, :Class, :Subclass, :Order, :Suborder, :Family]
  end

  def self.ranks_above_species
    [:Stirps, :Subsection, :Section, :Subgenus, :Genus,
     :Family, :Order, :Class, :Phylum, :Kingdom, :Domain]
  end

  def self.ranks_below_genus
    [:Form, :Variety, :Subspecies, :Species,
     :Stirps, :Subsection, :Section, :Subgenus]
  end

  def self.ranks_below_species
    [:Form, :Variety, :Subspecies]
  end

  def at_or_below_genus?
    rank == :Genus || below_genus?
  end

  def below_genus?
    Name.ranks_below_genus.include?(rank) ||
      rank == :Group && text_name.include?(" ")
  end

  def between_genus_and_species?
    below_genus? && !at_or_below_species?
  end

  def at_or_below_species?
    (rank == :Species) || Name.ranks_below_species.include?(rank)
  end

  def self.rank_index(rank)
    Name.all_ranks.index(rank.to_sym)
  end

  def rank_index(rank)
    Name.all_ranks.index(rank.to_sym)
  end

  def self.compare_ranks(a, b)
    all_ranks.index(a.to_sym) <=> all_ranks.index(b.to_sym)
  end

  def has_eol_data?
    if ok_for_export && !deprecated && MO.eol_ranks_for_export.member?(rank)
      observations.each do |o|
        if o.vote_cache && o.vote_cache >= MO.eol_min_observation_vote
          o.images.each do |i|
            if i.ok_for_export && i.vote_cache &&
               i.vote_cache >= MO.eol_min_image_vote
              return true
            end
          end
        end
      end
      descriptions.each do |d|
        return true if d.review_status == :vetted && d.ok_for_export && d.public
      end
    end
    false
  end

  # Returns an Array of all of this Name's ancestors, starting with its
  # immediate parent, running back to Eukarya.  It ignores misspellings.  It
  # chooses at random if there are more than one accepted parent taxa at a
  # given level.  (See comments for +parents+.)
  #
  #    child = Name.find_by_text_name('Letharia vulpina')
  #    child.all_parents.each do |parent|
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
  #   parent.all_children.each do |child|
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
  # matching genera, it prefers accepted ones that are not "sensu xxx".
  # Beyond that it just chooses the first one arbitrarily.
  def genus
    @genus ||= begin
      return unless text_name.include?(" ")
      genus_name = text_name.split(" ", 2).first
      genera     = Name.where(text_name: genus_name, correct_spelling_id: nil)
      accepted   = genera.reject(&:deprecated)
      genera     = accepted if accepted.any?
      nonsensu   = genera.reject { |n| n.author =~ /^sensu / }
      genera     = nonsensu if nonsensu.any?
      genera.first
    end
  end

  # Returns an Array of all Name's in the rank above that contain this Name.
  # If there are multiple names at a given rank, it prefers accepted, non-sensu
  # names, but beyond that it chooses the first one arbitrarily.  It ignores
  # misspellings.
  #
  #    child = Name.find_by_text_name('Letharia vulpina')
  #    child.parents.each do |parent|
  #      puts parent.text_name
  #    end
  #
  #    # Produces:
  #    Letharia (First) Author
  #    Letharia (Another) One
  #
  def parents(all = false)
    parents = []

    # Start with infrageneric and genus names.
    # Get rid of quoted words and ssp., var., f., etc.
    words = text_name.split(" ") - ["group", "clade", "complex"]
    words.pop
    until words.empty?
      name = words.join(" ")
      words.pop
      next if name == text_name || name[-1] == "."
      parent = Name.best_match(name)
      parents << parent if parent
      return [parent] if !all && parent && !parent.deprecated
    end

    # Next grab the names out of the classification string.
    lines = try(&:parse_classification) || []
    lines.reverse.each do |_line_rank, line_name|
      parent = Name.best_match(line_name)
      parents << parent if parent
      return [parent] if !all && !parent.deprecated
    end

    # Get rid of deprecated names unless all the results are deprecated.
    parents.reject!(&:deprecated) unless parents.all?(&:deprecated)

    # Return single parent as an array for backwards compatibility.
    return parents if all
    return [] unless parents.any?
    [parents.first]
  end

  # Handy method which searches for a plain old text name and picks the "best"
  # version available.  That is, it ignores misspellings, chooses accepted,
  # non-"sensu" names where possible, and finally picks the first one
  # arbitrarily where there is still ambiguity.  Useful if you just need a
  # name and it's not so critical that it be the exactly correct one.
  def self.best_match(name)
    matches  = Name.where(search_name: name, correct_spelling_id: nil)
    return matches.first if matches.any?
    matches  = Name.where(text_name: name, correct_spelling_id: nil)
    accepted = matches.reject(&:deprecated)
    matches  = accepted if accepted.any?
    nonsensu = matches.reject { |match| match.author =~ /^sensu / }
    matches  = nonsensu if nonsensu.any?
    matches.first
  end

  # Returns an Array of Name's directly under this one.  Ignores misspellings,
  # but includes deprecated Name's.
  #
  #   parent = Name.find_by_text_name('Letharia')
  #   parent.children.each do |child|
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
  #   parent.children.each do |child|
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
  def children(all = false)
    sql = at_or_below_genus? ?
          "text_name LIKE '#{text_name} %'" :
          "classification LIKE '%#{rank}: _#{text_name}_%'"
    sql += " AND correct_spelling_id IS NULL"
    return Name.where(sql).to_a if all
    Name.all_ranks.reverse.each do |rank2|
      next if rank_index(rank2) >= rank_index(rank)
      matches = Name.where("rank = #{Name.ranks[rank2]} AND #{sql}")
      return matches.to_a if matches.any?
    end
    []
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
      raise :runtime_user_bad_rank.t(rank: rank) if rank_index(rank).nil?
      rank_idx = [rank_index(:Genus), rank_index(rank)].max
      rank_str = "rank_#{rank}".downcase.to_sym.l

      # Check parsed output to make sure ranks are correct, names exist, etc.
      kingdom = "Fungi"
      parse_classification(text).each do |line_rank, line_name|
        real_rank = Name.guess_rank(line_name)
        real_rank_str = "rank_#{real_rank}".downcase.to_sym.l
        expect_rank = if ranks_between_kingdom_and_genus.include?(line_rank)
                        line_rank
                      else
                        :Genus # cannot guess Kingdom or Domain
                      end
        line_rank_str = "rank_#{line_rank}".downcase.to_sym.l
        line_rank_idx = rank_index(line_rank)
        if line_rank_idx.nil?
          raise :runtime_user_bad_rank.t(rank: line_rank_str)
        end
        if line_rank_idx <= rank_idx
          raise :runtime_invalid_rank.t(line_rank: line_rank_str,
                                        rank: rank_str)
        end
        if parsed_names[line_rank]
          raise :runtime_duplicate_rank.t(rank: line_rank_str)
        end
        if real_rank != expect_rank && kingdom == "Fungi"
          raise :runtime_wrong_rank.t(expect: line_rank_str,
                                      actual: real_rank_str, name: line_name)
        end
        parsed_names[line_rank] = line_name
        kingdom = line_name if line_rank == :Kingdom
      end

      # Reformat output, writing out lines in correct order.
      if parsed_names != {}
        result = ""
        Name.all_ranks.reverse.each do |rank|
          if (name = parsed_names[rank])
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
      text.split(/\r?\n/).each do |line|
        match = line.match(/^\s*([a-zA-Z]+):\s*_*([a-zA-Z]+)_*\s*$/)
        if match
          line_rank = match[1].downcase.capitalize.to_sym
          if (alt_rank = alt_ranks[line_rank])
            line_rank = alt_rank
          end
          line_name = match[2]
          results.push([line_rank, line_name])
        elsif !line.blank?
          raise :runtime_invalid_classification.t(text: line)
        end
      end
    end
    results
  end

  # Pass off to class method of the same name.
  def validate_classification(str = nil)
    self.class.validate_classification(str || classification)
  end

  # Pass off to class method of the same name.
  def parse_classification(str = nil)
    self.class.parse_classification(str || classification)
  end

  # Does this Name have notes (presumably discussing taxonomy).
  def has_notes?
    notes && notes.match(/\S/)
  end

  def text_before_rank
    text_name.split(" " + rank.to_s.downcase).first
  end

  # This is called before a name is created to let us populate things like
  # classification and lifeform from the parent (if infrageneric only).
  def inherit_stuff
    return unless genus # this sets the name instance @genus as side-effect
    self.classification ||= genus.classification
    self.lifeform       ||= genus.lifeform
  end

  # Let attached observations update their cache if these fields changed.
  def update_observation_cache
    Observation.update_cache("name", "lifeform", id, lifeform) \
      if lifeform_changed?
    Observation.update_cache("name", "text_name", id, text_name) \
      if text_name_changed?
    Observation.update_cache("name", "classification", id, classification) \
      if classification_changed?
  end

  # Copy classification from parent.  Just take parent's classification string
  # and add the parent's name to the bottom of it.  Nice and easy.
  def inherit_classification(parent)
    raise("missing parent!")               if !parent
    raise("only do this on genera or up!") if below_genus?
    raise("parent has no classification!") if parent.classification.blank?
    str = parent.classification.to_s.sub(/\s+\z/, "")
    str += "\r\n#{parent.rank}: _#{parent.text_name}_\r\n"
    change_classification(str)
  end

  # Change this name's classification.  Change parent genus, too, if below
  # genus.  Propagate to subtaxa if changing genus.
  def change_classification(new_str)
    root = below_genus? && genus || self
    root.update_attributes(classification: new_str)
    root.description.update_attributes(classification: new_str) if
      root.description_id
    root.propagate_classification if root.rank == :Genus
  end

  # Copy the classification of a genus to all of its children.  Does not change
  # updated_at or rss_log or anything.  Just changes the classification field
  # in the name and default description records.
  def propagate_classification
    raise("Name#propagate_classification only works on genera for now.") \
      if rank != :Genus
    escaped_string = Name.connection.quote(classification)
    Name.connection.execute(%(
      UPDATE names SET classification = #{escaped_string}
      WHERE text_name LIKE "#{text_name} %"
        AND classification != #{escaped_string}
    ))
    Name.connection.execute(%(
      UPDATE name_descriptions nd, names n
      SET nd.classification = #{escaped_string}
      WHERE nd.id = n.description_id
        AND n.text_name LIKE "#{text_name} %"
        AND nd.classification != #{escaped_string}
    ))
    Name.connection.execute(%(
      UPDATE observations
      SET classification = #{escaped_string}
      WHERE text_name LIKE "#{text_name} %"
        AND classification != #{escaped_string}
    ))
  end

  # This is meant to be run nightly to ensure that all the infrageneric
  # classifications are up-to-date with respect to their genera.  This is
  # important because there is no way to edit this on-line.  (Although there
  # will be a "propagate classification" button on the genera, and maybe we
  # can add that to the children, as well.)
  def self.propagate_generic_classifications
    out = []
    errors = {}
    genus_text_name = nil
    genus_classification = nil
    genus_rank = Name.ranks[:Genus]
    # The sort_name ordering should ensure that genera always come before
    # the corresponding infrageneric taxa.
    Name.connection.select_rows(%(
      SELECT id, description_id, rank, text_name, classification FROM names
      WHERE correct_spelling_id IS NULL
        AND rank <= #{genus_rank}
      ORDER BY sort_name ASC
    )).each do |id, desc_id, rank, text_name, classification|
      if rank == genus_rank
        genus_text_name = text_name
        genus_classification = classification
      elsif (x = text_name.split(" ", 2).first) != genus_text_name
        out << "Missing genus #{x}" unless errors[x]
        errors[x] = true
      elsif classification != genus_classification &&
            !genus_classification.blank?
        out << "Updating #{text_name}"
        str = Name.connection.quote(genus_classification)
        Name.connection.execute(%(
          UPDATE names SET classification = #{str} WHERE id = #{id}
        ))
        unless desc_id.blank?
          Name.connection.execute(%(
            UPDATE name_descriptions SET classification = #{str}
            WHERE id = #{desc_id}
          ))
        end
        Name.connection.execute(%(
          UPDATE observations SET classification = #{str} WHERE name_id = #{id}
        ))
      end
    end
    out
  end

  # This is meant to be run nightly to ensure that all the classification
  # caches are up to date.  It only pays attention to genera or higher.
  def self.refresh_classification_caches
    Name.connection.execute(%(
      UPDATE names n, name_descriptions nd
      SET n.classification = nd.classification
      WHERE nd.id = n.description_id
        AND n.rank <= #{Name.ranks[:Genus]}
        AND nd.classification != n.classification
        AND COALESCE(nd.classification, "") != ""
    ))
    []
  end

  ##############################################################################
  #
  #  :section: Lifeforms
  #
  ##############################################################################

  ALL_LIFEFORMS = [
    "basidiolichen",
    "lichen",
    "lichen_ally",
    "lichenicolous"
  ]

  def self.all_lifeforms
    ALL_LIFEFORMS
  end

  # This will include "lichen", "lichenicolous" and "lichen-ally" -- the usual
  # set of taxa lichenologists are interested in.
  def is_lichen?
    lifeform.include?("lichen")
  end

  # This excludes "lichen" but includes "mushroom" (so that truly lichenized
  # basidiolichens with mushroom fruiting bodies are included).
  def not_lichen?
    !lifeform.include?(" lichen ")
  end

  validate :validate_lifeform

  # Sorts and uniquifies the lifeform words, and complains about any that are
  # not recognized.  It adds an extra space before and after to ensure that it
  # is easy to search for entire words instead of just substrings.  That is,
  # one can do this:
  #
  #   lifeform.include(" word ")
  #
  # and be confident that it will not skip "word" at the beginning or end,
  # and will not match "compoundword".
  def validate_lifeform
    words = lifeform.to_s.split(" ").sort.uniq
    self.lifeform = words.any? ? " #{words.join(' ')} " : " "
    unknown_words = words - ALL_LIFEFORMS
    return unless unknown_words.any?
    unknown_words = unknown_words.map(&:inspect).join(", ")
    errors.add(:lifeform, :validate_invalid_lifeform.t(words: unknown_words))
  end

  # Add lifeform (one word only) to all children.
  def propagate_add_lifeform(lifeform)
    concat_str = Name.connection.quote("#{lifeform} ")
    search_str = Name.connection.quote("% #{lifeform} %")
    Name.connection.execute(%(
      UPDATE names SET lifeform = CONCAT(lifeform, #{concat_str})
      WHERE id IN (#{all_children.map(&:id).join(",")})
        AND lifeform NOT LIKE #{search_str}
    ))
    Name.connection.execute(%(
      UPDATE observations SET lifeform = CONCAT(lifeform, #{concat_str})
      WHERE name_id IN (#{all_children.map(&:id).join(",")})
        AND lifeform NOT LIKE #{search_str}
    ))
  end

  # Remove lifeform (one word only) from all children.
  def propagate_remove_lifeform(lifeform)
    replace_str = Name.connection.quote(" #{lifeform} ")
    search_str  = Name.connection.quote("% #{lifeform} %")
    Name.connection.execute(%(
      UPDATE names SET lifeform = REPLACE(lifeform, #{replace_str}, " ")
      WHERE id IN (#{all_children.map(&:id).join(",")})
        AND lifeform LIKE #{search_str}
    ))
    Name.connection.execute(%(
      UPDATE observations SET lifeform = REPLACE(lifeform, #{replace_str}, " ")
      WHERE name_id IN (#{all_children.map(&:id).join(",")})
        AND lifeform LIKE #{search_str}
    ))
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
        # Slightly faster than below since id is primary index.
        Name.where(id: @synonym_ids).to_a
      elsif synonym_id
        # This is apparently faster than synonym.names.
        Name.where(synonym_id: synonym_id).to_a
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
        Name.where(id: @other_author_ids).to_a
      else
        Name.where(text_name: text_name).to_a
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
    return unless synonym_id
    names = synonyms

    # Get rid of the synonym if only one going to be left in it.
    if names.length <= 2
      synonym.destroy
      names.each do |n|
        n.synonym_id = nil
        # n.accepted_name = n
        n.save
      end

    # Otherwise, just detach this name.
    else
      self.synonym_id = nil
      save
    end

    # This has to apply to names that are misspellings of this name, too.
    Name.where(correct_spelling: self).each do |n|
      n.update_attribute!(correct_spelling: nil)
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
      transfer_synonym(name)

    # *This* name has no synonyms, transfer us over to it.
    elsif !synonym_id
      name.transfer_synonym(self)

    # Both have synonyms -- merge them.
    # (Make sure they aren't already synonymized!)
    elsif synonym_id != name.synonym_id
      name.synonyms.each { |n| transfer_synonym(n) }
    end

    # synonym.choose_accepted_name
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
    unless synonym_id
      self.synonym = Synonym.create
      save
    end

    # Only transfer it over if it's not already a synonym!
    return unless synonym_id != name.synonym_id

    # Destroy old synonym if only one name left in it.
    name.synonym.destroy if name.synonym && (name.synonyms.length <= 2)

    # Attach name to our synonym.
    name.synonym_id = synonym_id
    name.save
  end

  def observation_count
    observations.length
  end

  # Returns either self or name,
  # whichever has more observations or was last used.
  def more_popular(name)
    result = self
    unless name.deprecated
      if deprecated
        result = name
      elsif observation_count < name.observation_count
        result = name
      elsif time_of_last_naming < name.time_of_last_naming
        result = name
      end
    end
    result
  end

  # (if no namings, returns created_at)
  def time_of_last_naming
    @time_of_last_naming ||= begin
      last_use = Name.connection.select_value("SELECT MAX(created_at) FROM namings WHERE name_id = #{id}")
      last_use || created_at
    end
  end

  ##############################################################################
  #
  #  :section: Misspellings
  #
  ##############################################################################

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
        Name.where(id: @misspelling_ids).to_a
      else
        Name.where(correct_spelling_id: id).to_a
      end
    end
  end

  # Do some simple queries to try to find alternate spellings of the given
  # (incorrectly-spelled) name.  Returns Array of Name instances.
  def self.suggest_alternate_spellings(str)
    results = []

    # Do some really basic pre-parsing, stripping off author and spuh.
    str = clean_incoming_string(str).
          tr("ë", "e").
          sub(/ sp\.?$/, "").
          tr("_", " ").strip_squeeze.capitalize_first
    str = parse_author(str).first # (strip author off)

    # Guess genus first, then species, and so on.
    unless str.blank?
      words = str.split
      num = words.length
      results = guess_word("", words.first)
      (2..num).each do |i|
        if results.any?
          if (i & 1) == 0
            prefixes = results.map(&:text_name).uniq
            results = []
            word = (i == 2) ? words[i - 1] : "#{words[i - 2]} #{words[i - 1]}"
            prefixes.each { |prefix| results |= guess_word(prefix, word) }
          end
        end
      end
    end

    results
  end

  private

  # Guess correct name of partial string.
  def self.guess_word(prefix, word) # :nodoc:
    str = "#{prefix} #{word}"
    results = guess_with_errors(str, 1)
    results = guess_with_errors(str, 2) if results.empty?
    results = guess_with_errors(str, 3) if results.empty?
    results
  end

  # Look up name replacing n letters at a time with a star.
  def self.guess_with_errors(name, n) # :nodoc:
    patterns = []

    # Restrict search to names close in length.
    a = name.length - 2
    b = name.length + 2

    # Create a bunch of SQL "like" patterns.
    name = name.gsub(/ \w+\. /, " % ")
    words = name.split
    (0..(words.length - 1)).each do |i|
      word = words[i]
      if word != "%"
        if word.length < n
          patterns << guess_pattern(words, i, "%")
        else
          (0..(word.length - n)).each do |j|
            sub = ""
            sub += word[0..(j - 1)] if j > 0
            sub += "%"
            sub += word[(j + n)..(-1)] if j + n < word.length
            patterns << guess_pattern(words, i, sub)
          end
        end
      end
    end

    # Create SQL query out of these patterns.
    conds = patterns.map do |pat|
      "text_name LIKE #{Name.connection.quote(pat)}"
    end.join(" OR ")
    conds = "(LENGTH(text_name) BETWEEN #{a} AND #{b}) AND (#{conds}) " \
            "AND correct_spelling_id IS NULL"
    names = where(conds).limit(10).to_a

    # Screen out ones way too different.
    names = names.reject do |x|
      (x.text_name.length < a) ||
        (x.text_name.length > b)
    end

    names
  end

  # String words together replacing the one at index +i+ with +sub+.
  def self.guess_pattern(words, i, sub) # :nodoc:
    result = []
    (0..(words.length - 1)).each do |j|
      result << (i == j ? sub : words[j])
    end
    result.join(" ")
  end

  public

  # Check if the reason that the given name (String) is unrecognized is because
  # it's within a deprecated genus.  Use case: Cladina has been included back
  # within Cladonia, but tons of guides use Cladina anyway, so people like to
  # enter novel names under Cladina, not realizing those names already exist
  # under Cladonia. Returns the parent in question which is deprecated (Name).
  def self.parent_if_parent_deprecated(str)
    result = nil
    names = find_or_create_name_and_parents(str)
    if names.any? && names.last && names.last.deprecated
      for name in names.reverse
        return name if name.id
      end
    end
    result
  end

  # Checks if the deprecated parent has synonyms, and if so, checks if there
  # is a corresponding child under on of the synonymous parents.  Returns an
  # Array of candidates (Name's).
  # str = "Agaricus bogus var. namus"
  def self.names_from_synonymous_genera(str, parent = nil)
    parent ||= parent_if_parent_deprecated(str) # parent = <Agaricus>
    parse = parse_name(str)
    result = []
    if parent && parse
      # child = "bogus var. namus"
      child = parse.real_text_name.sub(/^#{parent.real_text_name}/, "").strip
      # child_pat = "bog% var. nam%"
      child_pat = child.gsub(/(a|um|us)( |$)/, '%\2')
      # synonym = <Lepiota>
      parent.synonyms.each do |synonym|
        # "Lepiota bog% var. nam%"
        conditions = ["text_name like ? AND correct_spelling_id IS NULL",
                      synonym.text_name + " " + child_pat]
        result += Name.where(conditions).select do |name|
          # name = <Lepiota boga var. nama>
          valid_alternate_genus?(name, synonym.text_name, child_pat)
        end
      end
      # Return only valid candidates if any are valid.
      result.reject!(&:deprecated) if result.any? { |n| !n.deprecated? }
    end
    result
  end

  # The SQL pattern, e.g., "Lepiota test%", is too permissive.  Verify that the
  # results really are of the form /^Lepiota test(a|us|um)$/.
  def self.valid_alternate_genus?(name, parent, child_pat)
    unless match = name.text_name.match(/^#{parent} #{child_pat.gsub('%', '(.*)')}$/)
      return false
    end
    (1..child_pat.count("%")).each do |i|
      return false unless match[i].match(/^(a|us|um)$/)
    end
    true
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
  GROUP_ABBR   = / group | gr\.? | gp\.? | clade | complex /xi
  AUCT_ABBR    = / auct\.? /xi
  INED_ABBR    = / in\s?ed\.? /xi
  NOM_ABBR     = / nomen | nom\.? /xi
  COMB_ABBR    = / combinatio | comb\.? /xi
  SENSU_ABBR   = / sensu?\.? /xi
  NOV_ABBR     = / nova | novum | nov\.? /xi
  PROV_ABBR    = / provisional | prov\.? /xi
  CRYPT_ABBR   = / crypt\.? \s temp\.? /xi

  ANY_SUBG_ABBR   = / #{SUBG_ABBR} | #{SECT_ABBR} | #{SUBSECT_ABBR} |
                      #{STIRPS_ABBR} /x
  ANY_SSP_ABBR    = / #{SSP_ABBR} | #{VAR_ABBR} | #{F_ABBR} /x
  ANY_NAME_ABBR   = / #{ANY_SUBG_ABBR} | #{SP_ABBR} | #{ANY_SSP_ABBR} |
                      #{GROUP_ABBR} /x
  ANY_AUTHOR_ABBR = / (?: #{AUCT_ABBR} | #{INED_ABBR} | #{NOM_ABBR} |
                          #{COMB_ABBR} | #{SENSU_ABBR} | #{CRYPT_ABBR} )
                      (?:\s|$) /x

  UPPER_WORD = / [A-Z][a-zë\-]*[a-zë] | "[A-Z][a-zë\-\.]*[a-zë]" /x
  LOWER_WORD = / (?!sensu\b) [a-z][a-zë\-]*[a-zë] | "[a-z][\wë\-\.]*[\wë]" /x
  BINOMIAL   = / #{UPPER_WORD} \s #{LOWER_WORD} /x
  LOWER_WORD_OR_SP_NOV = / (?! sp\s|sp$|species) #{LOWER_WORD} |
                           sp\.\s\S*\d\S* /x

  # Matches the last epithet in a (standardized) name,
  # including preceding abbreviation if there is one.
  LAST_PART = / (?: \s[a-z]+\.? )? \s \S+ $/x

  AUTHOR_START = / #{ANY_AUTHOR_ABBR} | van\s | de\s | [
                   A-ZÀÁÂÃÄÅÆÇĐÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞČŚŠ\(] | "[^a-z\s] /x

  # AUTHOR_PAT is separate from, and can't include GENUS_OR_UP_TAXON, etc.
  #   AUTHOR_PAT ensures "sp", "ssp", etc., aren't included in author.
  #   AUTHOR_PAT removes the author first thing.
  # Then the other parsers have a much easier job.
  AUTHOR_PAT =
    /^
      ( "?
        #{UPPER_WORD}
        (?:
            # >= 1 of (rank Epithet)
            \s     #{ANY_SUBG_ABBR} \s #{UPPER_WORD}
            (?: \s #{ANY_SUBG_ABBR} \s #{UPPER_WORD} )* "?
          |
            \s (?! #{AUTHOR_START} | #{ANY_SUBG_ABBR} ) #{LOWER_WORD}
            (?: \s #{ANY_SSP_ABBR} \s #{LOWER_WORD} )* "?
          |
            "? \s #{SP_ABBR}
        )?
      )
      ( \s (?! #{ANY_NAME_ABBR} \s ) #{AUTHOR_START}.* )
    $/x

  # Taxa without authors (for use by GROUP PAT)
  # rubocop:disable Metrics/LineLength
  GENUS_OR_UP_TAXON = /("? (?:Fossil-)? #{UPPER_WORD} "?) (?: \s #{SP_ABBR} )?/x
  SUBGENUS_TAXON    = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD}) "?)/x
  SECTION_TAXON     = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD}) "?)/x
  SUBSECTION_TAXON  = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SUBSECT_ABBR} \s #{UPPER_WORD}) "?)/x
  STIRPS_TAXON      = /("? #{UPPER_WORD} \s (?: #{SUBG_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{SUBSECT_ABBR} \s #{UPPER_WORD} \s)?
                       (?: #{STIRPS_ABBR} \s #{UPPER_WORD}) "?)/x
  SPECIES_TAXON     = /("? #{UPPER_WORD} \s #{LOWER_WORD_OR_SP_NOV} "?)/x
  # rubocop:enable Metrics/LineLength

  GENUS_OR_UP_PAT = /^ #{GENUS_OR_UP_TAXON} (\s #{AUTHOR_START}.*)? $/x
  SUBGENUS_PAT    = /^ #{SUBGENUS_TAXON}    (\s #{AUTHOR_START}.*)? $/x
  SECTION_PAT     = /^ #{SECTION_TAXON}     (\s #{AUTHOR_START}.*)? $/x
  SUBSECTION_PAT  = /^ #{SUBSECTION_TAXON}  (\s #{AUTHOR_START}.*)? $/x
  STIRPS_PAT      = /^ #{STIRPS_TAXON}      (\s #{AUTHOR_START}.*)? $/x
  SPECIES_PAT     = /^ #{SPECIES_TAXON}     (\s #{AUTHOR_START}.*)? $/x
  SUBSPECIES_PAT  = /^ ("? #{BINOMIAL} (?: \s #{SSP_ABBR} \s #{LOWER_WORD}) "?)
                       (\s #{AUTHOR_START}.*)?
                   $/x
  VARIETY_PAT     = /^ ("? #{BINOMIAL} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{VAR_ABBR} \s #{LOWER_WORD}) "?)
                       (\s #{AUTHOR_START}.*)?
                   $/x
  FORM_PAT        = /^ ("? #{BINOMIAL} (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{VAR_ABBR} \s #{LOWER_WORD})?
                         (?: \s #{F_ABBR} \s #{LOWER_WORD}) "?)
                       (\s #{AUTHOR_START}.*)?
                   $/x

  GROUP_PAT       = /^(?<taxon>
                        #{GENUS_OR_UP_TAXON} |
                        #{SUBGENUS_TAXON}    |
                        #{SECTION_TAXON}     |
                        #{SUBSECTION_TAXON}  |
                        #{STIRPS_TAXON}      |
                        #{SPECIES_TAXON}     |
                        (?: "? #{UPPER_WORD} # infra-species taxa
                          (?: \s #{LOWER_WORD}
                            (?: \s #{SSP_ABBR} \s #{LOWER_WORD})?
                            (?: \s #{VAR_ABBR} \s #{LOWER_WORD})?
                            (?: \s #{F_ABBR}   \s #{LOWER_WORD})?
                          )? "?
                        )
                      )
                      (
                        ( # group, optionally followed by author
                          \s #{GROUP_ABBR} (\s (#{AUTHOR_START}.*))?
                        )
                        | # or
                        ( # author followed by group
                          ( \s (#{AUTHOR_START}.*)) \s #{GROUP_ABBR}
                        )
                      )
                    $/x

  # group or clade part of name, with
  # <group_wd> capture group capturing the stripped group or clade abbr
  GROUP_CHUNK     = /\s (?<group_wd>#{GROUP_ABBR}) \b/x

  # parsing a string to a Name
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
        text_name: @text_name,
        search_name: @search_name,
        sort_name: @sort_name,
        display_name: @display_name,
        author: @author,
        rank: @rank
      }
    end

    def inspect
      params.merge(parent_name: @parent_name).inspect
    end
  end

  # Parse a name given no additional information. Returns a ParsedName instance.
  def self.parse_name(str, rank: :Genus, deprecated: false)
    str = clean_incoming_string(str)
    parse_group(str, deprecated) ||
      parse_subgenus(str, deprecated) ||
      parse_section(str, deprecated) ||
      parse_subsection(str, deprecated) ||
      parse_stirps(str, deprecated) ||
      parse_subspecies(str, deprecated) ||
      parse_variety(str, deprecated) ||
      parse_form(str, deprecated) ||
      parse_species(str, deprecated) ||
      parse_genus_or_up(str, deprecated, rank)
  end

  # Guess rank of +text_name+.
  def self.guess_rank(text_name)
    text_name.match(/ (group|clade|complex)$/) ? :Group :
    text_name.include?(" f. ")         ? :Form       :
    text_name.include?(" var. ")       ? :Variety    :
    text_name.include?(" subsp. ")     ? :Subspecies :
    text_name.include?(" stirps ")     ? :Stirps     :
    text_name.include?(" subsect. ")   ? :Subsection :
    text_name.include?(" sect. ")      ? :Section    :
    text_name.include?(" subgenus ")   ? :Subgenus   :
    text_name.include?(" ")            ? :Species    :
    text_name.match(/^\S+aceae$/)      ? :Family     :
    text_name.match(/^\S+ineae$/)      ? :Family     : # :Suborder
    text_name.match(/^\S+ales$/)       ? :Order      :
    text_name.match(/^\S+mycetidae$/)  ? :Order      : # :Subclass
    text_name.match(/^\S+mycetes$/)    ? :Class      :
    text_name.match(/^\S+mycotina$/)   ? :Class      : # :Subphylum
    text_name.match(/^\S+mycota$/)     ? :Phylum     :
    text_name.match(/^Fossil-/)        ? :Phylum     :
                                         :Genus
  end

  def self.parse_author(str)
    str = clean_incoming_string(str)
    results = [str, nil]
    if (match = AUTHOR_PAT.match(str))
      results = [match[1].strip, match[2].strip]
    end
    results
  end

  def self.parse_group(str, deprecated = false)
    return unless (match = GROUP_PAT.match(str))

    result = parse_name(str_without_group(str),
                        rank: :Group, deprecated: deprecated)
    return nil unless result

    # Adjust the parsed name
    group_type = standardized_group_abbr(str)

    result.text_name += " #{group_type}"

    if result.author.present?
      # Add "clade" or "group" before author
      author = Regexp.escape(result.author)
      result.search_name.sub!( /(#{author})$/, "#{group_type} \\1")
      result.sort_name.sub!(   /(#{author})$/, " #{group_type}  \\1")
      result.display_name.sub!(/(#{author})$/, "#{group_type} \\1")
    else
      # Append "group" at end
      result.search_name +=  " #{group_type}"
      result.sort_name +=    "   #{group_type}"
      result.display_name += " #{group_type}"
    end

    result.rank = :Group
    result.parent_name ||= ""

    result
  end

  def self.str_without_group(str)
    str.sub(GROUP_CHUNK, "")
  end

  def self.standardized_group_abbr(str)
    word = group_wd(str.to_s.downcase)
    word =~ /^g/ ? "group" : word
  end

  # sripped group_abbr
  def self.group_wd(str)
    (GROUP_CHUNK.match(str))[:group_wd]
  end

  def self.parse_genus_or_up(str, deprecated = false, rank = :Genus)
    results = nil
    if (match = GENUS_OR_UP_PAT.match(str))
      name = match[1]
      author = match[2]
      rank = guess_rank(name) unless Name.ranks_above_genus.include?(rank)
      (name, author, rank) = fix_autonym(name, author, rank)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " " + author
      text_name = name.tr("ë", "e")
      parent_name = Name.ranks_below_genus.include?(rank) ?
                      name.sub(LAST_PART, "") : nil
      display_name = format_autonym(name, author, rank, deprecated)
      results = ParsedName.new(
        text_name: text_name,
        search_name: text_name + author2,
        sort_name: format_sort_name(text_name, author),
        display_name: display_name,
        parent_name: parent_name,
        rank: rank,
        author: author
      )
    end
    results
  rescue RankMessedUp
    return nil
  end

  def self.parse_below_genus(str, deprecated, rank, pattern)
    results = nil
    if match = pattern.match(str)
      name = match[1]
      author = match[2].to_s
      name = standardize_sp_nov_variants(name) if rank == :Species
      (name, author, rank) = fix_autonym(name, author, rank)
      name = standardize_name(name)
      author = standardize_author(author)
      author2 = author.blank? ? "" : " " + author
      text_name = name.tr("ë", "e")
      parent_name = name.sub(LAST_PART, "")
      display_name = format_autonym(name, author, rank, deprecated)
      results = ParsedName.new(
        text_name: text_name,
        search_name: text_name + author2,
        sort_name: format_sort_name(text_name, author),
        display_name: display_name,
        parent_name: parent_name,
        rank: rank,
        author: author
      )
    end
    results
  rescue RankMessedUp
    return nil
  end

  def self.parse_subgenus(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subgenus, SUBGENUS_PAT)
  end

  def self.parse_section(str, deprecated = false)
    parse_below_genus(str, deprecated, :Section, SECTION_PAT)
  end

  def self.parse_subsection(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subsection, SUBSECTION_PAT)
  end

  def self.parse_stirps(str, deprecated = false)
    parse_below_genus(str, deprecated, :Stirps, STIRPS_PAT)
  end

  def self.parse_species(str, deprecated = false)
    parse_below_genus(str, deprecated, :Species, SPECIES_PAT)
  end

  def self.parse_subspecies(str, deprecated = false)
    parse_below_genus(str, deprecated, :Subspecies, SUBSPECIES_PAT)
  end

  def self.parse_variety(str, deprecated = false)
    parse_below_genus(str, deprecated, :Variety, VARIETY_PAT)
  end

  def self.parse_form(str, deprecated = false)
    parse_below_genus(str, deprecated, :Form, FORM_PAT)
  end

  def self.parse_rank_abbreviation(str)
    str.match(SUBG_ABBR) ? :Subgenus : str.match(SECT_ABBR) ? :Section :
    str.match(SUBSECT_ABBR) ? :Subsection :
    str.match(STIRPS_ABBR) ? :Stirps :
    str.match(SSP_ABBR) ? :Subspecies :
    str.match(VAR_ABBR) ? :Variety : str.match(F_ABBR) ? :Form : nil
  end

  # Standardize various ways of writing sp. nov.  Convert to: Amanita "sp-T44"
  def self.standardize_sp_nov_variants(name)
    words = name.split(" ")
    if words.length > 2
      genus = words[0]
      epithet = words[2]
      epithet.sub!(/^"(.*)"$/, '\1')
      name = "#{genus} \"sp-#{epithet}\""
    else
      name.sub!(/ "sp\./i, ' "sp-')
    end
    name
  end

  # Fix common error: Amanita vaginatae Author var. vaginatae
  # Convert to: Amanita vaginatae var. vaginatae Author
  def self.fix_autonym(name, author, rank)
    last_word = name.split(" ").last.gsub(/[()]/, "")
    if match = author.to_s.match(/^(.*?)(( (#{ANY_SUBG_ABBR}|#{ANY_SSP_ABBR}) #{last_word})+)$/)
      name = "#{name}#{match[2]}"
      author = match[1].strip
      words = match[2].split(" ")
      while words.any?
        next_rank = parse_rank_abbreviation(words.shift)
        words.shift
        make_sure_ranks_ordered_right!(rank, next_rank)
        rank = next_rank
      end
    end
    [name, author, rank]
  end

  class RankMessedUp < ::StandardError
  end

  def self.make_sure_ranks_ordered_right!(prev_rank, next_rank)
    if compare_ranks(prev_rank, next_rank) <= 0 ||
       Name.ranks_above_species.include?(prev_rank) &&
       Name.ranks_below_species.include?(next_rank)
      raise RankMessedUp.new
    end
  end

  # Format a name ranked below genus, moving the author to before the var.
  # in natural varieties such as
  # "__Acarospora nodulosa__ (Dufour) Hue var. __nodulosa__".
  def self.format_autonym(name, author, _rank, deprecated)
    words = name.split(" ")
    if author.blank?
      format_name(name, deprecated)
    elsif words[-7] == words[-1]
      [
        format_name(words[0..-7].join(" "), deprecated),
        author,
        words[-6],
        format_name(words[-5], deprecated),
        words[-4],
        format_name(words[-3], deprecated),
        words[-2],
        format_name(words[-1], deprecated)
      ].join(" ")
    elsif words[-5] == words[-1]
      [
        format_name(words[0..-5].join(" "), deprecated),
        author,
        words[-4],
        format_name(words[-3], deprecated),
        words[-2],
        format_name(words[-1], deprecated)
      ].join(" ")
    elsif words[-3] == words[-1]
      [
        format_name(words[0..-3].join(" "), deprecated),
        author,
        words[-2],
        format_name(words[-1], deprecated)
      ].join(" ")
    else
      format_name(name, deprecated) + " " + author
    end
  end

  def self.standardize_name(str)
    words = str.split(" ")
    # every other word, starting next-from-last, is an abbreviation
    i = words.length - 2
    while i > 0
      if words[i].match(/^f/i)
        words[i] = "f."
      elsif words[i].match(/^v/i)
        words[i] = "var."
      elsif words[i].match(/^sect/i)
        words[i] = "sect."
      elsif words[i].match(/^stirps/i)
        words[i] = "stirps"
      elsif words[i].match(/^subg/i)
        words[i] = "subgenus"
      elsif words[i].match(/^subsect/i)
        words[i] = "subsect."
      else
        words[i] = "subsp."
      end
      i -= 2
    end
    words.join(" ")
  end

  def self.standardize_author(str)
    str = str.to_s.
          sub(/^ ?#{AUCT_ABBR}/,  "auct. ").
          sub(/^ ?#{INED_ABBR}/,  "ined. ").
          sub(/^ ?#{NOM_ABBR}/,   "nom. ").
          sub(/^ ?#{COMB_ABBR}/,  "comb. ").
          sub(/^ ?#{SENSU_ABBR}/, "sensu ").
          # Having fixed comb. & nom., standardize their suffixes
          sub(/(?<=comb. |nom. ) ?#{NOV_ABBR}/,  "nov. ").
          sub(/(?<=comb. |nom. ) ?#{PROV_ABBR}/, "prov. ").
          strip_squeeze
    squeeze_author(str)
  end

  # Squeeze "A. H. Smith" into "A.H. Smith".
  def self.squeeze_author(str)
    str.gsub(/([A-Z]\.) (?=[A-Z]\.)/, '\\1')
  end

  # Add italics and boldface markup to a standardized name (without author).
  def self.format_name(str, deprecated = false)
    boldness = deprecated ? "" : "**"
    words = str.split(" ")
    if words.length.even?
      genus = words.shift
      words[0] = genus + " " + words[0]
    end
    i = words.length - 1
    while i >= 0
      words[i] = "#{boldness}__#{words[i]}__#{boldness}"
      i -= 2
    end

    words.join(" ")
  end

  def self.clean_incoming_string(str)
    str.to_s.
      gsub(/“|”/, '"'). # let RedCloth format quotes
      gsub(/‘|’/, "'").
      gsub(/\u2028/, ""). # line separator that we see occasionally
      strip_squeeze
  end

  # Adjust +search_name+ string to collate correctly. Pass in +search_name+.
  def self.format_sort_name(name, author)
    str = format_name(name, :deprecated).
          sub(/^_+/, "").
          gsub(/_+/, " "). # put genus at the top
          sub(/ "(sp[\-\.])/, ' {\1'). # put "sp-1" at end
          gsub(/"([^"]*")/, '\1'). # collate "baccata" with baccata
          sub(" subgenus ", " {1subgenus ").
          sub(" sect. ",    " {2sect. ").
          sub(" subsect. ", " {3subsect. ").
          sub(" stirps ",   " {4stirps ").
          sub(" subsp. ",   " {5subsp. ").
          sub(" var. ",     " {6var. ").
          sub(" f. ", " {7f. ").
          strip.
          sub(/(^\S+)aceae$/,        '\1!7').
          sub(/(^\S+)ineae$/,        '\1!6').
          sub(/(^\S+)ales$/,         '\1!5').
          sub(/(^\S+?)o?mycetidae$/, '\1!4').
          sub(/(^\S+?)o?mycetes$/,   '\1!3').
          sub(/(^\S+?)o?mycotina$/,  '\1!2').
          sub(/(^\S+?)o?mycota$/,    '\1!1')
    1 while str.sub!(/(^| )([A-Za-z\-]+) (.*) \2( |$)/, '\1\2 \3 !\2\4') # put autonyms at the top

    if author.present?
      str += "  " + author.
             gsub(/"([^"]*")/, '\1'). # collate "baccata" with baccata
             gsub(/[Đđ]/, "d"). # mysql isn't collating these right
             gsub(/[Øø]/, "O").
             strip
    end
    str
  end

  ##############################################################################
  #
  #  :section: Creating Names
  #
  ##############################################################################

  # Short-hand for calling Name.find_names with +fill_in_authors+ set to +true+.
  def self.find_names_filling_in_authors(in_str, rank = nil,
                                         ignore_deprecated = false)
    find_names(in_str, rank, ignore_deprecated, :fill_in_authors)
  end

  # Look up Name's with a given name.  By default tries to weed out deprecated
  # Name's, but if that results in an empty set, then it returns the deprecated
  # ones. Returns an Array of zero or more Name instances.
  #
  # +in_str+::              String to parse.
  # +rank+::                Accept only names of this rank (optional).
  # +ignore_deprecated+::   If +true+, return all matching names,
  #                         even if deprecated.
  # +fill_in_authors+::     If +true+, will fill in author for Name's missing
  #                         authors
  #                         if +in_str+ supplies one.
  #
  #  names = Name.find_names('Letharia vulpina')
  #
  def self.find_names(in_str, rank = nil, ignore_deprecated = false,
                      fill_in_authors = false)

    return [] unless parse = parse_name(in_str)

    text_name = parse.text_name
    search_name = parse.search_name
    author = parse.author
    results = []

    while results.empty?
      conditions = []
      conditions_args = {}
      if author.present?
        conditions << "search_name = :name"
        conditions_args[:name] = search_name
      else
        conditions << "text_name = :name"
        conditions_args[:name] = text_name
      end
      conditions << "deprecated = 0" unless ignore_deprecated
      conditions << "rank = #{Name.ranks[rank]}" if rank

      results = Name.where(conditions.join(" AND "), conditions_args).to_a

      # If user provided author, check if name already exists without author.
      if author.present? && results.empty?
        conditions_args[:name] = text_name
        results = Name.where(conditions.join(" AND "), conditions_args).to_a
        # (this should never return more than one result)
        if fill_in_authors && results.length == 1
          results.first.change_author(author)
          results.first.save
        end
      end

      # Try again, looking for deprecated names
      # if didn't find any matching approved names.
      break if ignore_deprecated
      ignore_deprecated = true
    end

    results
  end

  # Parses a String, creates a Name for it and all its ancestors (if any don't
  # already exist), returns it in an Array (genus first, then species, etc.  If
  # there is ambiguity at any level (due to different authors), then +nil+ is
  # returned in that slot.  Check last slot especially.  Returns an Array of
  # Name instances, *UNSAVED*!!
  #
  #   names = Name.find_or_create_name_and_parents('Letharia vulpina (L.) Hue')
  #   raise "Name is ambiguous!" if !names.last
  #   names.each do |name|
  #     name.save if name and name.new_record?
  #   end
  #
  def self.find_or_create_name_and_parents(in_str)
    result = []
    if (parsed_name = parse_name(in_str))
      result = find_or_create_parsed_name_and_parents(parsed_name)
    end
    result
  end

  def self.find_or_create_parsed_name_and_parents(parsed_name)
    result = []
    if names_for_unknown.member?(parsed_name.search_name.downcase)
      result << Name.unknown
    else
      if parsed_name.parent_name
        result = find_or_create_name_and_parents(parsed_name.parent_name)
      end
      deprecate = result.any? && result.last && result.last.deprecated
      result << find_or_create_parsed_name(parsed_name, deprecate)
    end
    result
  end

  def self.find_or_create_parsed_name(parsed_name, deprecate = false)
    result = nil
    matches = find_matching_names(parsed_name)
    if matches.empty?
      result = Name.make_name(parsed_name.params)
      result.change_deprecated(true) if deprecate
    elsif matches.length == 1
      result = matches.first
      # Fill in author automatically if we can.
      if result.author.blank? && !parsed_name.author.blank?
        result.change_author(parsed_name.author)
      end
    else
      # Try to resolve ambiguity by taking the one with author.
      matches.reject! { |name| name.author.blank? }
      result = matches.first if matches.length == 1
    end
    result
  end

  def self.find_matching_names(parsed_name)
    result = []
    if parsed_name.author.blank?
      result = Name.where(text_name: parsed_name.text_name)
    else
      result = Name.where(search_name: parsed_name.search_name)
      if result.empty?
        result = Name.where(text_name: parsed_name.text_name, author: "")
      end
    end
    result.to_a
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
    matches = Name.where(search_name: search_name)
    if matches.empty?
      result = Name.new_name(params)
    elsif matches.length == 1
      result = matches.first
    end
    result
  end

  # make a Name given all the various name formats, etc.
  # Used only by +make_name+, +new_name_from_parsed_name+, and
  # +create_test_name+ in unit test.
  # Returns a Name instance, *UNSAVED*!!
  def self.new_name(params)
    result = Name.new(params)
    result.created_at = now = Time.now
    result.updated_at = now
    result
  end

  # Make a Name instance from a ParsedName
  # Used by NameController#create_new_name
  # Returns a Name instance, *UNSAVED*!!
  def self.new_name_from_parsed_name(parsed_name)
    new_name(parsed_name.params)
  end

  # Get list of Names that are potential matches when creating a new name.
  # Takes results of Name.parse_name.  Used by NameController#create_name.
  # Three cases:
  #
  #   1. group with author       - only accept exact matches
  #   2. nongroup with author    - match names with correct author or no author
  #   3. any name without author - ignore authors completely when matching names
  #
  # If the user provides an author, but the only match has no author, then we
  # just need to add an author to the existing Name.  If the user didn't give
  # an author, but there are matches with an author, then it already exists
  # and we should just ignore the request.
  #
  def self.names_matching_desired_new_name(parsed_name)
    if parsed_name.rank == :Group
      Name.where(search_name: parsed_name.search_name)
    elsif parsed_name.author.empty?
      Name.where(text_name: parsed_name.text_name)
    else
      Name.where(text_name: parsed_name.text_name).
           where(author: [parsed_name.author, ""])
    end
  end

  ##############################################################################
  #
  #  :section: Changing Name
  #
  ##############################################################################

  # Changes the name, and creates parents as necessary.  Throws a RuntimeError
  # with error message if unsuccessful in any way.  Returns nothing. *UNSAVED*!!
  #
  # *NOTE*: It does not save the changes to itself, but if it has to create or
  # update any parents (and caller has requested it), _those_ do get saved.
  #
  def change_text_name(in_text_name, in_author, in_rank, save_parents = false)
    in_str = Name.clean_incoming_string("#{in_text_name} #{in_author}")
    parse = Name.parse_name(in_str, rank: in_rank, deprecated: deprecated)
    if !parse || parse.rank != in_rank
      raise :runtime_invalid_for_rank.t(rank: :"rank_#{in_rank.to_s.downcase}",
                                        name: in_str)
    end
    if parse.parent_name &&
       !Name.find_by_text_name(parse.parent_name)
      parents = Name.find_or_create_name_and_parents(parse.parent_name)
      if parents.last.nil?
        raise :runtime_unable_to_create_name.t(name: parse.parent_name)
      elsif save_parents
        parents.each { |n| n.save if n && n.new_record? }
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
    return if rank == :Group
    old_author = author
    new_author2 = new_author.blank? ? "" : " " + new_author
    self.author = new_author.to_s
    self.search_name  = text_name + new_author2
    self.sort_name    = Name.format_sort_name(text_name, new_author)
    self.display_name = Name.format_autonym(text_name, new_author, rank,
                                            deprecated)
  end

  # Changes deprecated status.  Updates formatted names, as well. *UNSAVED*!!
  #
  #   name.change_deprecated(true)
  #   name.save
  #
  def change_deprecated(deprecated)
    # remove existing boldness
    name = display_name.gsub(/\*\*([^*]+)\*\*/, '\1')
    unless deprecated
      # add new boldness
      name.gsub!(/(__[^_]+__)/, '**\1**')
      self.correct_spelling = nil
    end
    self.display_name = name
    self.deprecated = deprecated
    # synonym.choose_accepted_name if synonym
  end

  # Mark this name as "misspelled", make sure it is deprecated, record what the
  # correct spelling should be, make sure it is NOT deprecated, and make sure
  # it is a synonym of this name.  Saves any changes it needs to make to the
  # correct spelling, but only saves the changes to this name if you ask it to.
  def mark_misspelled(target_name, save = false)
    return if deprecated && misspelling && correct_spelling == target_name
    self.misspelling = true
    self.correct_spelling = target_name
    change_deprecated(true)
    merge_synonyms(target_name)
    target_name.clear_misspelled(:save) if target_name.is_misspelling?
    save_with_log(:log_name_deprecated, other: target_name.display_name) \
      if save
    change_misspelled_consensus_names
  end

  # Mark this name as "not misspelled", and saves the changes if you ask it to.
  def clear_misspelled(save = false)
    return unless misspelling || correct_spelling
    was = correct_spelling.display_name
    self.misspelling = false
    self.correct_spelling = nil
    save_with_log(:log_name_unmisspelled, other: was) if save
  end

  # Super quick and low-level update to make sure no observation names are
  # misspellings.
  def change_misspelled_consensus_names
    Observation.connection.execute(%(
      UPDATE observations SET name_id = #{correct_spelling_id}
      WHERE name_id = #{id}
    ))
  end

  ##############################################################################
  #
  #  :section: Merging
  #
  ##############################################################################

  # Is it safe to merge this Name with another?  If any information will get
  # lost we return false.  In practice only if it has Namings.
  def mergeable?
    namings.empty?
  end

  # Merge all the stuff that refers to +old_name+ into +self+.  Usually, no
  # changes are made to +self+, however it might update the +classification+
  # cache if the old name had a better one -- NOT SAVED!!  Then +old_name+ is
  # destroyed; all the things that referred to +old_name+ are updated and
  # saved.
  def merge(old_name)
    return if old_name == self
    xargs = {}

    # Move all observations over to the new name.
    old_name.observations.each do |obs|
      obs.name = self
      obs.save
    end

    # Move all namings over to the new name.
    old_name.namings.each do |name|
      name.name = self
      name.save
    end

    # Move all misspellings over to the new name.
    old_name.misspellings.each do |name|
      if name == self
        name.correct_spelling = nil
      else
        name.correct_spelling = self
      end
      name.save
    end

    # Move over any interest in the old name.
    Interest.where(target_type: "Name", target_id: old_name.id).each do |int|
      int.target = self
      int.save
    end

    # Move over any notifications on the old name.
    Notification.where(flavor: Notification.flavors[:name],
                       obj_id: old_name.id).each do |note|
      note.obj_id = id
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
    if !description && old_name.description
      self.description = old_name.description
    end

    # Update the classification cache if that changed in the process.
    if description &&
       (classification != description.classification)
      self.classification = description.classification
    end

    # Move over any remaining descriptions.
    old_name.descriptions.each do |desc|
      xargs = {
        id: desc,
        set_name: self
      }
      desc.name_id = id
      desc.save
    end

    # Log the action.
    if old_name.rss_log
      old_name.rss_log.orphan(old_name.display_name, :log_name_merged,
                              this: old_name.display_name, that: display_name)
    end

    # Destroy past versions.
    editors = []
    old_name.versions.each do |ver|
      editors << ver.user_id
      ver.destroy
    end

    # Update contributions for editors.
    editors.delete(old_name.user_id)
    editors.uniq.each do |user_id|
      SiteData.update_contribution(:del, :names_versions, user_id)
    end

    # Fill in citation if new name is missing one.
    if citation.blank? && !old_name.citation.blank?
      self.citation = old_name.citation.strip_squeeze
    end

    # Save any notes the old name had.
    if old_name.has_notes? && (old_name.notes != notes)
      if has_notes?
        self.notes += "\n\nThese notes come from #{old_name.format_name} when it was merged with this name:\n\n" +
                      old_name.notes
      else
        self.notes = old_name.notes
      end
      log(:log_name_updated, touch: true)
      save
    end

    # Finally destroy the name.
    old_name.destroy
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users
    return unless altered?

    sender = User.current
    recipients = []

    # Tell admins of the change.
    descriptions.map(&:admins).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_admin
      end
    end

    # Tell authors of the change.
    descriptions.map(&:authors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_author
      end
    end

    # Tell editors of the change.
    descriptions.map(&:editors).each do |user_list|
      user_list.each do |user|
        recipients.push(user) if user.email_names_editor
      end
    end

    # Tell reviewers of the change.
    descriptions.map(&:reviewer).each do |user|
      recipients.push(user) if user && user.email_names_reviewer
    end

    # Tell masochists who want to know about all name changes.
    User.where(email_names_all: true).each do |user|
      recipients.push(user)
    end

    # Send to people who have registered interest.
    # Also remove everyone who has explicitly said they are NOT interested.
    interests.each do |interest|
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end

    # Send notification to all except the person who triggered the change.
    (recipients.uniq - [sender]).each do |recipient|
      QueuedEmail::NameChange.create_email(sender, recipient, self, nil, false)
    end
  end

  # Resolves the name using these heuristics:
  #   First time through:
  #     Only 'what' will be filled in.
  #     Prompts the user if not found.
  #     Gives user a list of options if matches more than one. ('names')
  #     Gives user a list of options if deprecated. ('valid_names')
  #   Second time through:
  #     'what' is a new string if user typed new name, else same as old 'what'
  #     'approved_name' is old 'what'
  #     'chosen_name' hash on name.id: radio buttons
  #     Uses the name chosen from the radio buttons first.
  #     If 'what' has changed, then go back to "First time through" above.
  #     Else 'what' has been approved, create it if necessary.
  #
  # INPUTS:
  #   what            params[:name][:name]            Text field.
  #   approved_name   params[:approved_name]          Last name user entered.
  #   chosen_name     params[:chosen_name][:name_id]  Name id from radio boxes.
  #   (@user -- might be used by one or more things)
  #
  # RETURNS:
  #   success       true: okay to use name; false: user needs to approve name.
  #   name          Name object if it resolved without reservations.
  #   names         List of choices if name matched multiple objects.
  #   valid_names   List of choices if name is deprecated.
  #
  def self.resolve_name(what, approved_name, chosen_name)
    success = true
    name = nil
    names = nil
    valid_names = nil
    parent_deprecated = nil
    suggest_corrections = false

    what2 = what.to_s.tr("_", " ").strip_squeeze
    approved_name2 = approved_name.to_s.tr("_", " ").strip_squeeze

    unless what2.blank? || names_for_unknown.member?(what2.downcase)
      success = false

      ignore_approved_name = false
      # Has user chosen among multiple matching names or among
      # multiple approved names?
      if chosen_name.blank?
        # Look up name: can return zero (unrecognized), one
        # (unambiguous match), or many (multiple authors match).
        names = find_names_filling_in_authors(what2)
      else
        names = [find(chosen_name)]
        # This tells it to check if this name is deprecated below EVEN
        # IF the user didn't change the what field.  This will solve
        # the problem of multiple matching deprecated names discussed
        # below.
        ignore_approved_name = true
      end

      # Create temporary name object for it.  (This will not save anything
      # EXCEPT in the case of user supplying author for existing name that
      # has no author.)
      if names.empty? &&
         (name = create_needed_names(approved_name2, what2))
        names << name
      end

      # No matches -- suggest some correct names to make Debbie happy.
      if names.empty?
        if (parent = parent_if_parent_deprecated(what2))
          valid_names = names_from_synonymous_genera(what2, parent)
          parent_deprecated = parent
        else
          valid_names = suggest_alternate_spellings(what2)
          suggest_corrections = true
        end

      # Only one match (or we just created an approved new name).
      elsif names.length == 1
        target_name = names.first
        # Single matching name.  Check if it's deprecated.
        if target_name.deprecated &&
           (ignore_approved_name || (approved_name != what))
          # User has not explicitly approved the deprecated name: get list of
          # valid synonyms.  Will display them for user to choose among.
          valid_names = target_name.approved_synonyms
        else
          # User has selected an unambiguous, accepted name... or they have
          # chosen or approved of their choice.  Either way, go with it.
          name = target_name
          # Fill in author, just in case user has chosen between two authors.
          # If the form fails for some other reason and we don't do this, it
          # will ask the user to choose between the authors *again* later.
          what = name.real_search_name
          # (This is the only way to get out of here with success.)
          success = true
        end

      # Multiple matches.
      elsif names.length > 1
        if names.reject(&:deprecated).empty?
          # Multiple matches, all of which are deprecated.  Check if
          # they all have the same set of approved names.  Pain in the
          # butt, but otherwise can get stuck choosing between
          # Helvella infula Fr. and H. infula Schaeff. without anyone
          # mentioning that both are deprecated by Gyromitra infula.
          valid_set = Set.new
          names.each do |n|
            valid_set.merge(n.approved_synonyms)
          end
          valid_names = valid_set.sort_by(&:sort_name)
        end
      end
    end

    [success, what, name, names, valid_names, parent_deprecated,
     suggest_corrections]
  end

  def self.create_needed_names(input_what, output_what = nil)
    names = []
    if output_what.nil? || input_what == output_what
      names = find_or_create_name_and_parents(input_what)
      if names.last
        names.each do |n|
          next unless n && n.new_record?
          n.inherit_stuff
          n.save_with_log(:log_updated_by)
        end
      end
    end
    names.last
  end

  def self.save_names(names, deprecate)
    log = nil
    unless deprecate.nil?
      if deprecate
        log = :log_deprecated_by
      else
        log = :log_approved_by
      end
    end
    names.each do |n|
      next unless n && n.new_record?
      n.change_deprecated(deprecate) if deprecate
      n.inherit_stuff
      n.save_with_log(log)
    end
  end

  def save_with_log(log = nil, args = {})
    return false unless changed?
    log ||= :log_name_updated
    args = { touch: altered? }.merge(args)
    log(log, args)
    save
  end

  ##############################################################################
  #
  #  :section: Limits
  #
  ##############################################################################

  # :string field size limits in characters, based on this algorithm:
  # Theoretical max differences between (text_name + author) and the field
  #   search_name: 4
  #     Adding a " sp." at the end is the worst case.
  #   sort_name:   21
  #     It adds " {N" and " !" (5 chars) in front of subgenus and the epithet
  #     that goes with it. There can be up to 4 infrageneric ranks (subgenus,
  #     section, subsection, stirps, plus the space between name and author.
  #     That adds up to 5*4 + 1 = 21.
  #   display_name: 41
  #     Adds the space between name and author; "**__" and "__**" (8 chars)
  #     around every epithet, grouping genus and species. Infrageneric ranks
  #     win, making as many as 5 separate bold epithets or epithet pairs.
  #     That adds up to 8*5 + 1 = 41.

  # Numbers are hard-coded (rather than calculated) to make it easier to copy
  # them to migrations.

  # An arbitrary number intended to be large enough for all Names
  def self.text_name_limit
    100
  end

  # An arbitary number intended to be large enough to include all abbreviated
  # authors. There are now some Names with > text_name_limit worth of authors.
  # Rather than increase this limit, we will suggest that multiple authors be
  # listed as "first_author & al." per ICN Recommendation 46C.2.
  def self.author_limit
    100
  end

  # text_name_limit + author_limit + 4
  def self.search_name_limit
    204
  end

  # text_name_limit + author_limit + 21
  def self.sort_name_limit
    221
  end

  # text_name_limit + author_limit + 41
  def self.display_name_limit
    241
  end

  ##############################################################################

  private

  validate :check_user, :check_text_name, :check_author

  # :stopdoc:
  def check_author
    return if author.to_s.size <= Name.author_limit
    errors.add(
      :author,
      "#{:validate_name_author_too_long.t} #{:MAXIMUM.t}: "\
      "#{Name.author_limit}. #{:validate_name_use_first_author.t}."
    )
  end

  def check_text_name
    return if text_name.to_s.size <= Name.text_name_limit
    errors.add(
      :text_name,
      "#{:validate_name_text_name_too_long.t} #{:MAXIMUM.t}: "\
      "#{Name.text_name_limit}"
    )
  end

  def check_user
    errors.add(:user, :validate_name_user_missing.t) if !user && !User.current
  end
end
