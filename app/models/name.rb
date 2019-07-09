# frozen_string_literal: true
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
#  sort_name::        (V) "Xanthoparmelia" coloradoensis Fries
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
#  display_name_brief_authors:: Marked up name with authors shortened:
#                            **__"Xxx yyy__ author**
#                            **__"Xxx yyy__ author1 & author2**
#                            **__"Xxx yyy__ author1 et al.**
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
#  best_approved_synonym::   Single "best" approved synonym
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
class Name < AbstractModel
  require "acts_as_versioned"
  require "fileutils"

  require_dependency "name/change"
  require_dependency "name/create"
  require_dependency "name/format"
  require_dependency "name/lifeform"
  require_dependency "name/merge"
  require_dependency "name/spelling"
  require_dependency "name/notify"
  require_dependency "name/parse"
  require_dependency "name/primer"
  require_dependency "name/resolve"
  require_dependency "name/synonymy"
  require_dependency "name/taxonomy"
  require_dependency "name/validation"

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

  belongs_to :correct_spelling,
             class_name: "Name",
             foreign_key: "correct_spelling_id"
  belongs_to :description, class_name: "NameDescription",
                           inverse_of: :name # (main one)
  belongs_to :rss_log
  belongs_to :synonym

  belongs_to :user

  has_many :descriptions, -> { order "num_views DESC" },
           class_name: "NameDescription",
           inverse_of: :name
  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target
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

  def <=>(other)
    sort_name <=> other.sort_name
  end

  def best_brief_description
    (description.gen_desc.presence || description.diag_desc) if description
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
end
