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
#    sort_name          "Xanthoparmelia" coloradoensis Fries
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
#  Changes are kept in the "name_versions" table using
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
#  rank::             (V) "Species", "Genus", "Order", etc.
#  icn_id             (V) numerical identifier issued by an
#                         ICN-recognized registration repository
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
#  all_ranks::               Ranks: all. Defined by enum.
#  ranks_above_genus::       Ranks: above "Genus".
#  ranks_below_genus::       Ranks: below "Genus".
#  ranks_above_species::     Ranks: above "Species".
#  ranks_below_species::     Ranks: below "Species".
#  alt_ranks::               Ranks: map alternatives to our values.
#
#  ==== Scopes
#  created_on("yyyymmdd")
#  created_after("yyyymmdd")
#  created_before("yyyymmdd")
#  created_between(start, end)
#  updated_on("yyyymmdd")
#  updated_after("yyyymmdd")
#  updated_before("yyyymmdd")
#  updated_between(start, end)
#  deprecated
#  has_description
#  description_has
#  has_description_in_project(project)
#  has_description_created_by(user)
#  has_description_reviewed_by(user)
#  has_description_of_type(source_type)
#  with_correct_spelling
#  with_incorrect_spelling
#  with_self_referential_misspelling
#  has_synonyms
#  ok_for_export
#  rank(ranks)
#  with_rank(rank)
#  with_rank_below(rank)
#  with_rank_and_name_in_classification(rank, text_name)
#  with_rank_at_or_below_genus
#  with_rank_above_genus
#  subtaxa_of_genus_or_below(genus)
#  subtaxa_of(name)
#  include_synonyms_of(name)
#  clade(name)
#  text_name_has(text_name)
#  search_name_has(phrase)
#  has_classification
#  classification_has(classification)
#  has_author
#  author_has(author)
#  has_citation
#  citation_has(citation)
#  has_notes
#  notes_has(notes)
#  has_comments
#  comments_has(summary)
#  species_lists(species_list)
#  locations(location)
#  in_box(north:, south:, east:, west:)
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
#  format_name::             "**_Xxx sp.__** Author"
#  unique_text_name::        "Xxx (123)"
#  unique_format_name::      "**__Xxx sp.__** Author (123)"
#  unique_search_name::      Xxx yyy Author (123)
#  stripped_text_name        text_name minus quotes, periods, sp, group, etc.
#  display_name_brief_authors:: Marked up name with authors shortened:
#                            **__"Xxx yyy__ author**
#                            **__"Xxx yyy__ author1 & author2**
#                            **__"Xxx yyy__ author1 et al.**
#  change_text_name::        Change name, updating formats.
#  change_author::           Change author, updating formats.
#
#  ==== Propagation
#  can_propagate?::          Can Classification be propagated to subtaxa?
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
#  registrable?              Could it be registered in fungal nomenclature db?
#  unregistrable?            Not registrable?
#  searchable_in_registry?   Stripped text_name searchable in
#                            fungal nomenclature db
#  unsearchable_in_registry? not searchable_in_registry?
#
#  ==== Synonymy
#  synonyms:                 List of all synonyms, including this Name.
#  synonym_ids:              List of IDs of all synonyms, including this Name
#  other_synonyms:           List of all synonyms, excluding this Name.
#  other_synonym_ids::       List of IDs of all synonyms, excluding this Name
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
#  merger_destructive?::     Would merger into another Name destroy data?
#  merge::                   Merge old name into this one and remove old one.
#  dependents?::         Does another Name depend from this Name?
#
#  == Callbacks
#
#  create_description::      After create: create (empty) official
#                              NameDescription.
#  notify_users::            After save: notify interested User's of changes.
#
###############################################################################
class Name < AbstractModel
  require "acts_as_versioned"
  require "fileutils"
  require "symbol_extensions"

  # modules with instance methods and maybe class methods
  include Scopes
  include Validation
  include Taxonomy
  include Synonymy
  include Resolve
  include PropagateGenericClassifications
  include Notify
  include Spelling
  include Merge
  include Lifeform
  include Format
  include Change

  # modules with class methods only
  extend Parse
  extend Create

  # Do not change the integer associated with a value
  enum :rank, {
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
  }

  belongs_to :correct_spelling, class_name: "Name"
  belongs_to :description, class_name: "NameDescription",
                           inverse_of: :name # (main one)
  belongs_to :rss_log
  belongs_to :synonym

  belongs_to :user

  has_many :misspellings, class_name: "Name",
                          foreign_key: "correct_spelling_id",
                          inverse_of: :correct_spelling
  has_many :descriptions, -> { order(num_views: :desc) },
           class_name: "NameDescription",
           inverse_of: :name
  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target
  has_many :name_trackers
  has_many :namings
  has_many :observations

  acts_as_versioned(
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
      icn_id
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

  validates :author, allow_blank: true,
                     # Contains only: letters, spaces, parens, hyphens,
                     # periods, commas, ampersands, square brackets
                     format: { with: /\A[\p{L} ()-.,&\[\]]*\z/,
                               message: :validate_name_author_characters.t }
  validates :author, allow_blank: true,
                     # Ends only in letter, period plus any spaces
                     format: { with: /[\p{Alpha}\.]( *)\z/,
                               message: :validate_name_author_ending.t }
  validate  :author_length
  validate  :citation_start
  validates :icn_id, numericality: { allow_nil: true,
                                     only_integer: true,
                                     greater_than_or_equal_to: 1 }
  validate  :icn_id_registrable
  validate  :icn_id_unique
  validate  :lifeform_known
  validates :search_name, presence: true
  validate  :search_name_indistinct
  validate  :text_name_length
  validate  :user_presence

  before_create :inherit_stuff
  after_create :notify_webmaster

  before_update :update_observation_cache
  after_update :notify_users

  # Used by name/_form_name.rhtml
  attr_accessor :misspelling

  SEARCHABLE_FIELDS = [
    :search_name, :citation, :notes
  ].freeze

  # (Create should not be logged at all.  Update is already logged with more
  # sphistication than the autologger allows.  Merge will already log the
  # destruction as a merge and orphan the log.
  self.autolog_events = [:destroyed]

  # Callbacks whenever new version is created.
  versioned_class.before_save do |ver|
    ver.user_id = User.current_id || 0
    if (ver.version != 1) &&
       Name::Version.where(name_id: ver.name_id,
                           user_id: ver.user_id).none?
      UserStats.update_contribution(:add, :name_versions)
    end
  end

  # This is called before a name is created to let us populate things like
  # classification and lifeform from the parent (if infrageneric only).
  def inherit_stuff
    return unless accepted_genus

    self.classification ||= accepted_genus.classification
    self.lifeform       ||= accepted_genus.lifeform
  end

  # Let attached observations update their cache if these fields changed.
  # Also, `touch` if it changes the obs name and should invalidate HTML
  # caches of the observation.
  def update_observation_cache
    touch_cases = text_name_changed? || author_changed? || deprecated_changed?
    no_touch_cases = lifeform_changed? || classification_changed?
    return unless touch_cases || no_touch_cases

    updates = {}
    updates[:updated_at] = Time.zone.now if touch_cases && !no_touch_cases
    updates[:lifeform] = lifeform if lifeform_changed?
    updates[:text_name] = text_name if text_name_changed?
    updates[:classification] = classification if classification_changed?
    Observation.where(name_id: id).update_all(updates) if updates.present?
  end

  def <=>(other)
    sort_name <=> other.sort_name
  end

  def best_brief_description
    (description.gen_desc.presence || description.diag_desc) if description # rubocop:disable Style/RedundantParentheses
  end

  # Used by show_name.
  def self.count_observations(names)
    Hash[*Observation.group(:name_id).where(name: names).
         pluck(:name_id, Arel.star.count).to_a.flatten]
  end
end
