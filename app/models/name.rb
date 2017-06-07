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
#                          (minus authors, but with umlauts if exist)
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
#  ==== Editing
#  changeable?(user) ::      May user change this Name?
#
#  == Callbacks
#
#  create_description::      After create: create (empty) official
#                              NameDescription.
#  notify_users::            After save: notify interested User's of changes.
#
################################################################################

class Name < AbstractModel
  require "acts_as_versioned"
  require "fileutils"

  # enum definitions for use by simple_enum gem
  # Do not change the integer associated with a value
  as_enum(:rank,
          { Form: 1,
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
            Group: 16      # used for both "group" and "clade"
          },
          source: :rank,
          with: [],
          accessor: :whiny
         )

  belongs_to :correct_spelling, class_name: "Name", foreign_key: "correct_spelling_id"
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
    if_changed: %w(
      rank
      text_name
      search_name
      sort_name
      display_name
      author
      citation
      deprecated
      correct_spelling
      notes)
  )
  non_versioned_columns.push(
    "created_at",
    "updated_at",
    "num_views",
    "last_view",
    "ok_for_export",
    "rss_log_id",
    # 'accepted_name_id',
    "synonym_id",
    "description_id",
    "classification" # (versioned in the default desc)
  )

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

  def best_classification
    description.classification if description
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

  def is_lichen?
    # Check both this name and genus, just in case I'm missing some species.
    return true if Triple.where(subject: ":name/#{id}",
                                predicate: ":lichenAuthority").count > 0
    return false unless below_genus?
    genus_id = Name.where(text_name: text_name.split.first).select(:id).first
    Triple.where(subject: ":name/#{genus_id}",
                 predicate: ":lichenAuthority").count > 0
  end

  def has_eol_data?
    if ok_for_export && !deprecated && MO.eol_ranks_for_export.member?(rank)
      for o in observations
        if o.vote_cache && o.vote_cache >= MO.eol_min_observation_vote
          for i in o.images
            if i.ok_for_export && i.vote_cache && i.vote_cache >= MO.eol_min_image_vote
              return true
            end
          end
        end
      end
      for d in descriptions
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
    if below_genus?
      genus_name = text_name.split(" ").first
      Name.where(text_name: genus_name).reject(&:deprecated).first
    end
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
  def parents(all = false)
    results   = []
    lines     = nil
    next_rank = rank

    # Try ranks above ours one at a time until we find a parent.
    while all || results.empty?
      next_rank = Name.all_ranks[rank_index(next_rank) + 1]
      break if !next_rank || next_rank == :Group
      these = []

      # Once we go past genus we need to search the classification string.
      if Name.ranks_above_genus.include?(next_rank)

        unless lines
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
          lines = begin
                    parse_classification(str)
                  rescue
                    []
                  end
          break if lines.empty?
        end

        # Grab name for 'next_rank' from classification string.
        for line_rank, line_name in lines
          these += Name.where(text_name: line_name) if line_rank == next_rank
        end

      # At and below genus, we do a database query on part of our name, e.g.,
      # if our name is "Xxx yyy var. zzz", we search first for species named
      # "Xxx yyy", then genera named "Xxx".)
      elsif next_rank == :Variety && text_name.match(/^(.* var\. \S+)/) || next_rank == :Subspecies && text_name.match(/^(.* subsp\. \S+)/) ||
            next_rank == :Species && text_name.match(/^(\S+ \S+)/) || next_rank == :Genus && text_name.match(/^(\S+)/)
        str = Regexp.last_match(1)
        these = Name.where(correct_spelling_id: nil,
                           rank: Name.ranks[next_rank],
                           text_name: str
                          ).to_a
      end

      # Get rid of deprecated names unless all the results are deprecated.
      unless these.empty?
        unless these.count(&:deprecated) == these.length
          these = these.reject(&:deprecated)
        end
        if all
          results << these.first
        else
          results = these
        end
      end
    end

    results
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
  def children(all = false)
    results = []
    our_rank = rank
    our_index = rank_index(our_rank)

    # If we're above genus we need to rely on classification strings.
    if Name.ranks_above_genus.include?(our_rank)

      # Querying every genus that refers to this ancestor could potentially get
      # expensive -- think of doing children for Eukarya!! -- but I'm not sure
      # how else to do it.  (There are currently 1927 genera in the database.)
      rows = Name.connection.select_rows %(
        SELECT classification, search_name FROM names
        WHERE rank = #{Name.ranks[:Genus]}
          AND classification LIKE '%#{rank}: _#{text_name}_%'
      )

      # Genus should not be included in classifications.
      names = []
      if our_rank == :Family
        for cstr, sname in rows
          results += Name.where(search_name: sname).to_a
        end

      # Grab all names below our rank.
      elsif all
        # Get set of ranks between ours and genus.
        accept_ranks = Name.ranks_above_genus.
                       reject { |x| Name.all_ranks.index(x) >= our_index }.
                       map(&:to_s)
        # Search for names in each classification string.
        for cstr, sname in rows
          while cstr.sub!(/(\w+): _([^_]+)_\s*\Z/, "")
            line_rank = Regexp.last_match(1)
            line_name = Regexp.last_match(2)
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
          results += Name.where(search_name: sname).to_a
        end

      # Grab all names at next lower rank.
      else
        next_rank = Name.all_ranks[our_index - 1]
        match_str = "#{next_rank}: _"
        for cstr, sname in rows
          if (i = cstr.index(match_str)) &&
             cstr[i..-1].match(/_([^_]+)_/)
            names << Regexp.last_match(1)
          end
        end
      end

      # Convert these name strings into Names.
      results += names.uniq.map { |n| Name.where(text_name: n) }.flatten
      results.uniq!

      # Add subgeneric names for all genera in the results.
      if all
        results2 = []
        for name in results
          if name.rank == :Genus
            results2 += Name.where("correct_spelling_id IS NULL AND " \
                                   "text_name LIKE ? ' %'", name.text_name).to_a
          end
        end
        results += results2
      end

    # Get everything below our rank.
    else
      results = Name.where("correct_spelling_id IS NULL AND " \
                           "text_name LIKE ? ' %'", text_name).to_a

      # Remove subchildren if not getting all children.  This is trickier than
      # I originally expected because we want the children of G. species to
      # include the first two of these, but not the last:
      #   G. species var. variety            YES!!
      #   G. species f. form                 YES!!
      #   G. species var. variety f. form    NO!!
      unless all
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
      rank_idx = rank_index(rank)
      rank_str = "rank_#{rank}".downcase.to_sym.l
      fail :runtime_user_bad_rank.t(rank: rank) if rank_idx.nil?

      # Check parsed output to make sure ranks are correct, names exist, etc.
      kingdom = "Fungi"
      for line_rank, line_name in parse_classification(text)
        real_rank = Name.guess_rank(line_name)
        real_rank_str = "rank_#{real_rank}".downcase.to_sym.l
        if [:Phylum, :Subphylum, :Class, :Subclass, :Order, :Suborder, :Family].include?(line_rank)
          expect_rank = line_rank
        else
          expect_rank = :Genus # cannot guess Kingdom or Domain
        end
        line_rank_str = "rank_#{line_rank}".downcase.to_sym.l
        line_rank_idx = rank_index(line_rank)
        fail :runtime_user_bad_rank.t(rank: line_rank_str) if line_rank_idx.nil?
        fail :runtime_invalid_rank.t(line_rank: line_rank_str, rank: rank_str) if line_rank_idx <= rank_idx
        fail :runtime_duplicate_rank.t(rank: line_rank_str) if parsed_names[line_rank]
        fail :runtime_wrong_rank.t(expect: line_rank_str, actual: real_rank_str, name: line_name) if real_rank != expect_rank && kingdom == "Fungi"
        parsed_names[line_rank] = line_name
        kingdom = line_name if line_rank == :Kingdom
      end

      # Reformat output, writing out lines in correct order.
      if parsed_names != {}
        result = ""
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
          fail :runtime_invalid_classification.t(text: line)
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
        Name.where(id: @synonym_ids).to_a
      elsif synonym_id
        # Takes on average 0.050 seconds.
        Name.where(synonym_id: synonym_id).to_a

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
    if synonym_id
      names = synonyms

      # Get rid of the synonym if only one going to be left in it.
      if names.length <= 2
        synonym.destroy
        for n in names
          n.synonym_id = nil
          # n.accepted_name = n
          n.save
        end

      # Otherwise, just dettach this name.
      else
        old_synonym = synonym
        self.synonym_id = nil
        # self.accepted_name = self
        save
        # old_synonym.choose_accepted_name
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
      transfer_synonym(name)

    # *This* name has no synonyms, transfer us over to it.
    elsif !synonym_id
      name.transfer_synonym(self)

    # Both have synonyms -- merge them.
    # (Make sure they aren't already synonymized!)
    elsif synonym_id != name.synonym_id
      for n in name.synonyms
        transfer_synonym(n)
      end
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
    other_synonym = nil

    # Make sure this name is attached to a synonym, creating one if necessary.
    unless synonym_id
      self.synonym = Synonym.create
      save
    end

    # Only transfer it over if it's not already a synonym!
    if synonym_id != name.synonym_id

      # Destroy old synonym if only one name left in it.
      if name.synonym &&
         (name.synonyms.length <= 2)
        name.synonym.destroy
        other_synonym = (name.synonyms - [name]).first
      else
        other_synonym = name.synonym
      end

      # Attach name to our synonym.
      name.synonym_id = synonym_id
      name.save
    end

    # synonym.choose_accepted_name
    # other_synonym.choose_accepted_name if other_synonym
  end

  # Choose an accepted name for this name, saving the change.
  # def choose_accepted_name
  #   if synonym
  #     synonym.choose_accepted_name
  #   elsif accepted_name_id != id
  #     self.accepted_name = self
  #     self.save
  #   end
  # end

  def observation_count
    observations.length
  end

  # Returns either self or name, whichever has more observations or was last used.
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
      for i in 2..num
        if results.any?
          if (i & 1) == 0
            prefixes = results.map(&:text_name).uniq
            results = []
            word = (i == 2) ? words[i - 1] : "#{words[i - 2]} #{words[i - 1]}"
            for prefix in prefixes
              results |= guess_word(prefix, word)
            end
          end
        end
      end
    end

    results
  end

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
    for i in 0..(words.length - 1)
      word = words[i]
      if word != "%"
        if word.length < n
          patterns << guess_pattern(words, i, "%")
        else
          for j in 0..(word.length - n)
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
    conds = "(LENGTH(text_name) BETWEEN #{a} AND #{b}) AND (#{conds})"
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
    for j in 0..(words.length - 1)
      result << (i == j ? sub : words[j])
    end
    result.join(" ")
  end

  public

  # Check if the reason that the given name (String) is unrecognized is because
  # it's within a deprecated genus.  Use case: Cladina has been included back
  # within Cladonia, but tons of guides use Cladina anyway, so people like to
  # enter novel names under Cladina, not realizing that those names already exist
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
  def self.names_from_synonymous_genera(str, parent = nil) # str = "Agaricus bogus var. namus"
    parent ||= parent_if_parent_deprecated(str) # parent = <Agaricus>
    parse = parse_name(str)
    result = []
    if parent && parse
      child = parse.real_text_name.sub(/^#{parent.real_text_name}/, "").strip # child = "bogus var. namus"
      child_pat = child.gsub(/(a|um|us)( |$)/, '%\2')                         # child_pat = "bog% var. nam%"
      for synonym in parent.synonyms                                          # synonym = <Lepiota>
        target = synonym.text_name + " " + child                              # target = "Lepiota bog% var. nam%"
        conditions = ["text_name like ? AND correct_spelling_id IS NULL",
                      synonym.text_name + " " + child_pat]
        result += Name.where(conditions).select do |name|
          valid_alternate_genus?(name, synonym.text_name, child_pat)          # name = <Lepiota boga var. nama>
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
    for i in 1..child_pat.count("%")
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
  GROUP_ABBR   = / group | gr\.? | gp\.? | clade /xi
  AUCT_ABBR    = / auct\.? /xi
  INED_ABBR    = / in\s?ed\.? /xi
  NOM_ABBR     = / nomen | nom\.? /xi
  COMB_ABBR    = / combinatio | comb\.? /xi
  SENSU_ABBR   = / sensu?\.? /xi
  NOV_ABBR     = / nova | novum | nov\.? /xi
  PROV_ABBR    = / provisional | prov\.? /xi

  ANY_SUBG_ABBR   = / #{SUBG_ABBR} | #{SECT_ABBR} | #{SUBSECT_ABBR} |
                      #{STIRPS_ABBR} /x
  ANY_SSP_ABBR    = / #{SSP_ABBR} | #{VAR_ABBR} | #{F_ABBR} /x
  ANY_NAME_ABBR   = / #{ANY_SUBG_ABBR} | #{SP_ABBR} | #{ANY_SSP_ABBR} |
                      #{GROUP_ABBR} /x
  ANY_AUTHOR_ABBR = / (?: #{AUCT_ABBR} | #{INED_ABBR} | #{NOM_ABBR} |
                          #{COMB_ABBR} | #{SENSU_ABBR} ) (?:\s|$) /x

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
  GENUS_OR_UP_TAXON = /("? #{UPPER_WORD} "?) (?: \s #{SP_ABBR} )?/x
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

  # Parse a name given no additional information.  Returns a ParsedName instance.
  def self.parse_name(str, rank = :Genus, deprecated = false)
    str = clean_incoming_string(str)
    parse_group(str, deprecated) ||
      parse_subgenus(str, deprecated) ||
      parse_section(str, deprecated) || parse_subsection(str, deprecated) || parse_stirps(str, deprecated) || parse_subspecies(str, deprecated) || parse_variety(str, deprecated) || parse_form(str, deprecated) || parse_species(str, deprecated) || parse_genus_or_up(str, deprecated, rank)
  end

  # Guess rank of +text_name+.
  def self.guess_rank(text_name)
    text_name.match(/ (group|clade)$/) ? :Group :
    text_name.include?(" f. ") ? :Form :
    text_name.include?(" var. ") ? :Variety :
    text_name.include?(" subsp. ") ? :Subspecies :
    text_name.include?(" stirps ") ? :Stirps : text_name.include?(" subsect. ") ? :Subsection :
    text_name.include?(" sect. ") ? :Section :
    text_name.include?(" subgenus ") ? :Subgenus :
    text_name.include?(" ") ? :Species :
    text_name.match(/^\w+aceae$/) ? :Family :
    text_name.match(/^\w+ineae$/) ? :Family : # :Suborder
    text_name.match(/^\w+ales$/) ? :Order :
    text_name.match(/^\w+mycetidae$/) ? :Order : # :Subclass
    text_name.match(/^\w+mycetes$/) ? :Class :
    text_name.match(/^\w+mycotina$/) ? :Class : # :Subphylum
    text_name.match(/^\w+mycota$/) ? :Phylum :
                                        :Genus
  end

  def self.parse_author(str)
    str = clean_incoming_string(str)
    results = [str, nil]
    if match = AUTHOR_PAT.match(str)
      results = [match[1].strip, match[2].strip]
    end
    results
  end

  def self.parse_group(str, deprecated = false)
    return unless match = GROUP_PAT.match(str)

    result = parse_name(str_without_group(str))
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
    group_wd(str) == "clade" ? "clade" : "group"
  end

  # sripped group_abbr
  def self.group_wd(str)
    (GROUP_CHUNK.match(str))[:group_wd]
  end

  def self.parse_genus_or_up(str, deprecated = false, rank = :Genus)
    results = nil
    if match = GENUS_OR_UP_PAT.match(str)
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
      fail RankMessedUp.new
    end
  end

  # Format a name ranked below genus, moving the author to before the var.
  # in natural varieties such as "__Acarospora nodulosa__ (Dufour) Hue var. __nodulosa__".
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
          sub(/(^\w+)aceae$/, '\1!7').
          sub(/(^\w+)ineae$/,        '\1!6').
          sub(/(^\w+)ales$/,         '\1!5').
          sub(/(^\w+?)o?mycetidae$/, '\1!4').
          sub(/(^\w+?)o?mycetes$/,   '\1!3').
          sub(/(^\w+?)o?mycotina$/, '\1!2').
          sub(/(^\w+?)o?mycota$/, '\1!1')
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
  #   for name in names
  #     name.save if name and name.new_record?
  #   end
  #
  def self.find_or_create_name_and_parents(in_str)
    result = []
    if parsed_name = parse_name(in_str)
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

  # Return extant Names matching a desired new Name
  # Used by NameController#create_name
  def self.names_matching_desired_new_name(parsed_name)
    # authored :Group ParsedName must be matched exactly
    if parsed_name.rank == :Group
      Name.where(search_name: parsed_name.search_name)
    # unauthored ParsedName matches Names with or w/o authors
    elsif parsed_name.author.empty?
      Name.where(text_name: parsed_name.text_name)
    # authored non-:Group ParsedName matched by exact & authorless extant Names
    else
      Name.
        where(text_name: parsed_name.text_name).
        where(author: [parsed_name.author, ""])
    end
  end

  ################################################################################
  #
  #  :section: Changing Name
  #
  ################################################################################

  # May user edit this name?
  def changeable?(user = @user)
    noone_else_owns_references_to_name?(user)
  end

  def noone_else_owns_references_to_name?(user)
    all_references.each { |obj| return false if obj.user_id != user.id }
    true
  end

  # The references which a User must own in order to edit name
  def all_references
    namings + observations
  end

  # Return extant Names matching a desired changed Name
  # When matching a desired changed name, get exact matches.
  # This allows authored/unauthored pairs at all Ranks.
  # We assume than when editing a Name, a User is making a deliberate choice.
  # This contrasts with creating a Name, where we assume that the User may be
  # overlooking an extant Name.
  # Used by NameController#edit_name
  def self.names_matching_desired_changed_name(parsed_name)
    Name.where(search_name: parsed_name.search_name)
  end

  # Changes the name, and creates parents as necessary.  Throws a RuntimeError
  # with error message if unsuccessful in any way.  Returns nothing. *UNSAVED*!!
  #
  # *NOTE*: It does not save the changes to itself, but if it has to create or
  # update any parents (and caller has requested it), _those_ do get saved.
  #
  def change_text_name(in_text_name, in_author, in_rank, save_parents = false)
    in_str = Name.clean_incoming_string("#{in_text_name} #{in_author}")
    parse = Name.parse_name(in_str, in_rank, deprecated)
    if !parse || parse.rank != in_rank
      fail :runtime_invalid_for_rank.t(rank: :"rank_#{in_rank.to_s.downcase}", name: in_str)
    end
    if parse.parent_name &&
       !Name.find_by_text_name(parse.parent_name)
      parents = Name.find_or_create_name_and_parents(parse.parent_name)
      if parents.last.nil?
        fail :runtime_unable_to_create_name.t(name: parse.parent_name)
      elsif save_parents
        for n in parents
          n.save if n && n.new_record?
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
    if rank != :Group
      old_author = author
      new_author2 = new_author.blank? ? "" : " " + new_author
      self.author = new_author.to_s
      self.search_name  = text_name + new_author2
      self.sort_name    = Name.format_sort_name(text_name, new_author)
      self.display_name = Name.format_autonym(text_name, new_author, rank, deprecated)
    end
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
    end

    # Move all namings over to the new name.
    for name in old_name.namings
      name.name = self
      name.save
    end

    # Move all misspellings over to the new name.
    for name in old_name.misspellings
      if name == self
        name.correct_spelling = nil
      else
        name.correct_spelling = self
      end
      name.save
    end

    # Move over any interest in the old name.
    # for int in Interest.find_all_by_target_type_and_target_id('Name', old_name.id)
    for int in Interest.where(target_type: "Name", target_id: old_name.id)
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
    for desc in old_name.descriptions
      xargs = {
        id: desc,
        set_name: self
      }
      desc.name_id = id
      desc.save
    end

    # Log the action.
    old_name.rss_log.orphan(old_name.display_name, :log_name_merged,
                            this: old_name.display_name, that: display_name) if old_name.rss_log

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

  ################################################################################
  #
  #  :section: Callbacks
  #
  ################################################################################

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users
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
      for user in User.where(email_names_all: true)
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
        QueuedEmail::NameChange.create_email(sender, recipient, self, nil, false)
      end
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

    [success, what, name, names, valid_names, parent_deprecated, suggest_corrections]
  end

  def self.create_needed_names(input_what, output_what = nil)
    names = []
    if output_what.nil? || input_what == output_what
      names = find_or_create_name_and_parents(input_what)
      if names.last
        names.each do |n|
          n.save_with_log(:log_updated_by) if n && n.new_record?
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
    for n in names
      if n && n.new_record?
        n.change_deprecated(deprecate) if deprecate
        n.save_with_log(log)
      end
    end
  end

  def save_with_log(log = nil, args = {})
    return false unless changed?
    log ||= :log_name_updated
    args = { touch: altered? }.merge(args)
    log(log, args)
    save
  end

  ################################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    errors.add(:user, :validate_name_user_missing.t) if !user && !User.current

    if text_name.to_s.bytesize > 100
      errors.add(:text_name, :validate_name_text_name_too_long.t)
    end
    if search_name.to_s.bytesize > 200
      errors.add(:search_name, :validate_name_search_name_too_long.t)
    end
    if sort_name.to_s.bytesize > 200
      errors.add(:sort_name, :validate_name_sort_name_too_long.t)
    end
    if display_name.to_s.bytesize > 200
      errors.add(:display_name, :validate_name_display_name_too_long.t)
    end

    if author.to_s.bytesize > 100
      errors.add(:author, :validate_name_author_too_long.t)
    end
  end
end
