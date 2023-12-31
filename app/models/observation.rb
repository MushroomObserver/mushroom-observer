# frozen_string_literal: true

#  = Observation Model
#
#  An Observation is a mushroom seen at a certain Location and time, as
#  recorded by a User.  This is at the core of the site.  It can have any
#  number of Image's, Naming's, Comment's, Interest's.
#
#  == Voting
#
#  Voting is still in a state of flux.  At the moment User's create Naming's
#  and other User's Vote on them.  We combine the Vote's for each Naming, cache
#  the Vote for each Naming in the Naming.  However no Naming necessarily wins
#  -- instead Vote's are tallied for each Synonym (see calc_consensus for full
#  details).  Thus the accepted Name of the winning Synonym is cached in the
#  Observation along with its winning Vote score.
#
#  == Location
#
#  An Observation can belong to either a defined Location (+location+, a
#  Location instance) or an undefined one (+where+, just a String), and even
#  occasionally both (see below).  To make this a little easier, you can refer
#  to +place_name+ instead, which returns the name of whichever is present.
#
#  *NOTE*: We were clearly having trouble making up our mind whether or not to
#  set +where+ when +location+ was present.  The only safe heuristic is to use
#  +location+ if it's present, then fall back on +where+ -- +where+ may or may
#  not be set (or even accurate?) if +location+ is present.
#
#  *NOTE*: If a mushroom is seen at a mushroom fair or an herbarium, we don't
#  necessarily know where the mushroom actually grew.  In this case, we enter
#  the mushroom fair / herbarium as the +place_name+ and set the special flag
#  +is_collection_location+ to false.
#
#  == Attributes
#
#  id::                     Locally unique numerical id, starting at 1.
#  created_at::             Date/time it was first created.
#  updated_at::             Date/time it was last updated.
#  user_id::                User that created it.
#  when::                   Date it was seen.
#  where::                  Where it was seen (just a String).
#  location::               Where it was seen (Location).
#  lat::                    Exact latitude of location.
#  long::                   Exact longitude of location.
#  alt::                    Exact altitude of location. (meters)
#  is_collection_location:: Is this where it was growing?
#  gps_hidden::             Hide exact lat/long?
#  name::                   Consensus Name (never deprecated, never nil).
#  vote_cache::             Cache Vote score for the winning Name.
#  thumb_image::            Image to use as thumbnail (if any).
#  specimen::               Does User have a specimen available?
#  notes::                  Arbitrary text supplied by User and serialized.
#  num_views::              Number of times it has been viewed.
#  last_view::              Last time it was viewed.
#  log_updated_at::         Cache of RssLogs.updated_at, for speedier index
#
#  ==== "Fake" attributes
#  place_name::             Wrapper on top of +where+ and +location+.
#                           Handles location_format.
#
#  == Class methods
#
#  refresh_vote_cache::     Refresh cache for all Observation's.
#  define_a_location::      Update any observations using the old "where" name.
#  touch_when_logging::     Override of AbstractModel's hook when updating log
#  ---
#  no_notes::               value of observation.notes if there are no notes
#  no_notes_persisted::     no_notes persisted in the db
#  other_notes_key::        key used for general Observation notes
#  other_notes_part::       other_notes_key as a String
#  notes_part_id::          id of textarea for a Notes heading
#  notes_area_id_prefix     prefix for id of textarea for a Notes heading
#  export_formatted::       notes (or any hash) to string with marked up
#                           captions (keys)
#  show_formatted::         notes (or any hash) to string with plain
#                           captions (keys)
#
#  ==== Scopes
#
#  created_on("yyyymmdd")
#  created_after("yyyymmdd")
#  created_before("yyyymmdd")
#  created_between(start, end)
#  updated_on("yyyymmdd")
#  updated_after("yyyymmdd")
#  updated_before("yyyymmdd")
#  updated_between(start, end)
#  found_on("yyyymmdd")
#  found_after("yyyymmdd")
#  found_before("yyyymmdd")
#  found_between(start, end)
#  of_name(name)
#  of_name_like(string)
#  with_name
#  without_name
#  by_user(user)
#  with_location
#  without_location
#  at_location(location)
#  in_region(where)
#  in_box(n,s,e,w) geoloc is in the box
#  outside(n,s,e,w) geoloc is outside the box
#  is_collection_location
#  not_collection_location
#  with_image
#  without_image
#  with_notes
#  without_notes
#  has_notes_field(field)
#  notes_include(note)
#  with_specimen
#  without_specimen
#  with_sequence
#  without_sequence
#  confidence (min %, max %)
#  with_comments
#  without_comments
#  comments_include(summary)
#  for_project(project)
#  in_herbarium(herbarium)
#  herbarium_record_notes_include(notes)
#  on_species_list(species_list)
#  on_species_list_of_project(project)
#
#  == Instance methods
#
#  comments::               List of Comment's attached to this Observation.
#  interests::              List of Interest's attached to this Observation.
#  sequences::              List of Sequences which belong to this Observation.
#  species_lists::          List of SpeciesList's that contain this Observation.
#  other_notes_key::        key used for general Observation notes
#  other_notes_part::       other_notes_key as a String
#  notes_part_id::          id of textarea for a Notes heading
#  notes_part_value::       value for textarea for a Notes heading
#  form_notes_parts::       note parts to display in create & edit form
#  notes_normalized_key::   key (of the notes parts array)
#  notes_export_formatted:: notes to string with marked up captions (keys)
#  notes_show_formatted::   notes to string with plain captions (keys)
#
#  ==== Name Formats #  text_name::              Plain text.
#  format_name::            Textilized. (uses name.observation_name)
#  unique_text_name::       Plain text, with id added to make unique.
#  unique_format_name::     Textilized, with id added to make unique.
#
#  ==== Namings and Votes
#  name::                   Conensus Name instance. (never nil)
#  namings::                List of Naming's proposed for this Observation.
#  name_been_proposed?::    Has someone proposed this Name already?
#  owner_voted?::           Has the owner voted on a given Naming?
#  user_voted?::            Has a given User voted on a given Naming?
#  owners_vote::            Owner's Vote on a given Naming.
#  users_vote::             A given User's Vote on a given Naming
#  owners_votes::           Get all of the onwer's Vote's for this Observation.
#  owners_favorite?::       Is a given Naming one of the owner's favorite(s)
#                           for this Observation?
#  users_favorite?::        Is a given Naming one of the given user's
#                           favorites for this Observation?
#  owner_preference         owners's unique prefered Name (if any) for this Obs
#  change_vote::            Change a given User's Vote for a given Naming.
#  consensus_naming::       Guess which Naming is responsible for consensus.
#  calc_consensus::         Calculate and cache the consensus naming/name.
#  review_status::          Decide what the review status is for this Obs.
#  lookup_naming::          Return corresponding Naming instance from this
#                           Observation's namings association.
#  dump_votes::             Dump all the Naming and Vote info as known by this
#                           Observation and its associations.
#
#  ==== Images
#  images::                 List of Image's attached to this Observation.
#  add_image::              Attach an Image.
#  remove_image::           Remove an Image.
#
#  ==== Projects
#  can_edit?::              Check if user has permission to edit this obs.
#
#  ==== Callbacks
#  add_spl_callback::           After add: update contribution.
#  remove_spl_callback::        After remove: update contribution.
#  notify_species_lists::       Before destroy: log destruction on spls.
#  destroy_dependents::         After destroy: destroy Naming's.
#  notify_users_after_change::  After save: call notify_users (if important).
#  notify_users_before_destroy:: Before destroy: call notify_users.
#  notify_users::               After save/destroy/image: send email.
#  announce_consensus_change::  After consensus changes: send email.
#
class Observation < AbstractModel # rubocop:disable Metrics/ClassLength
  belongs_to :thumb_image, class_name: "Image",
                           inverse_of: :thumb_glossary_terms
  belongs_to :name # (used to cache consensus name)
  belongs_to :location
  belongs_to :rss_log
  belongs_to :user

  # Has to go before "has many interests" or interests will be destroyed
  # before it has a chance to notify the interested users of the destruction.
  before_destroy :notify_users_before_destroy

  has_many :votes
  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target
  has_many :sequences, dependent: :destroy
  has_many :external_links, dependent: :destroy

  # DO NOT use :dependent => :destroy -- this causes it to recalc the
  # consensus several times and send bogus emails!!
  has_many :namings

  has_many :observation_images, dependent: :destroy
  has_many :images, through: :observation_images

  has_many :project_observations, dependent: :destroy
  has_many :projects, through: :project_observations

  has_many :species_list_observations, dependent: :destroy
  has_many :species_lists, through: :species_list_observations,
                           after_add: :add_spl_callback,
                           before_remove: :remove_spl_callback

  has_many :observation_collection_numbers, dependent: :destroy
  has_many :collection_numbers, through: :observation_collection_numbers

  has_many :observation_herbarium_records, dependent: :destroy
  has_many :herbarium_records, through: :observation_herbarium_records

  has_many :observation_views, dependent: :destroy
  has_many :viewers, class_name: "User",
                     through: :observation_views,
                     source: :user

  # rubocop:disable Rails/ActiveRecordCallbacksOrder
  # else Rubocop says: "before_save is supposed to appear before before_destroy"
  # because a before_destroy must precede the has_many's
  before_save :cache_content_filter_data
  # rubocop:enable Rails/ActiveRecordCallbacksOrder
  after_update :notify_users_after_change
  before_destroy :destroy_orphaned_collection_numbers
  before_destroy :notify_species_lists
  after_destroy :destroy_dependents

  # Automatically (but silently) log destruction.
  self.autolog_events = [:destroyed]

  # NOTE: To improve Coveralls display, do not use one-line stabby lambda scopes
  # Extra timestamp scopes for when Observation found:
  scope :found_on, lambda { |ymd_string|
    where(arel_table[:when].format("%Y-%m-%d") == ymd_string)
  }
  scope :found_after, lambda { |ymd_string|
    where(arel_table[:when].format("%Y-%m-%d") >= ymd_string)
  }
  scope :found_before, lambda { |ymd_string|
    where(arel_table[:when].format("%Y-%m-%d") <= ymd_string)
  }
  scope :found_between, lambda { |earliest, latest|
    where(arel_table[:when].format("%Y-%m-%d") >= earliest).
      where(arel_table[:when].format("%Y-%m-%d") <= latest)
  }

  scope :with_name,
        -> { where.not(name: Name.unknown) }
  scope :without_name,
        -> { where(name: Name.unknown) }
  scope :with_name_above_genus,
        -> { where(name_id: Name.with_rank_above_genus.map(&:id)) }
  scope :without_confident_name,
        -> { where(vote_cache: ..0) }
  scope :needs_id, lambda {
    with_name_above_genus.or(without_confident_name)
  }

  scope :with_vote_by_user, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id
    joins(:votes).where(votes: { user_id: user_id })
  }
  scope :without_vote_by_user, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id
    where.not(id: Vote.where(user_id: user_id).map(&:observation_id).uniq)
  }
  scope :reviewed_by_user, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id
    joins(:observation_views).
      where(observation_views: { user_id: user_id, reviewed: 1 })
  }
  scope :not_reviewed_by_user, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id
    where.not(id: ObservationView.where(user_id: user_id, reviewed: 1).
              map(&:observation_id).uniq)
  }
  scope :needs_id_for_user, lambda { |user|
    needs_id.without_vote_by_user(user).not_reviewed_by_user(user).distinct
  }
  # Higher taxa: returns narrowed-down group of id'd obs,
  # in higher taxa under the given taxon
  # scope :needs_id_by_taxon, lambda { |user, name|
  #   name_plus_subtaxa = Name.include_subtaxa_of(name)
  #   subtaxa_above_genus = name_plus_subtaxa.with_rank_above_genus.map(&:id)
  #   lower_subtaxa = name_plus_subtaxa.with_rank_at_or_below_genus.map(&:id)

  #   where(name_id: subtaxa_above_genus).or(
  #     Observation.where(name_id: lower_subtaxa).and(
  #       Observation.where(vote_cache: ..0)
  #     )
  #   ).without_vote_by_user(user).not_reviewed_by_user(user).distinct
  # }

  # scope :of_name(name, **args)
  #
  # Accepts either a Name instance, a string, or an id as the first argument.
  #  Other args:
  #  - include_synonyms: boolean
  #  - include_subtaxa: boolean
  #  - include_all_name_proposals: boolean
  #  - of_look_alikes: boolean
  #
  scope :of_name, lambda { |name, **args|
    # First, get a name record if string or id submitted
    case name
    when String
      name = Name.find_by(text_name: name)
    when Integer
      name = Name.find_by(id: name)
    end
    return Observation.none unless name.is_a?(Name)

    # Filter args may add to an array of names to collect Observations
    names_array = [name]
    # Maybe add synonyms (Name#synonyms includes original name)
    names_array = name.synonyms if args[:include_synonyms]
    # Keep names_array intact as is; maybe add more to its clone name_ids.
    # (I'm thinking it's easier to pass name ids to the Observation query)
    name_ids = names_array.map(&:id)

    # Add subtaxa to name_ids array. Subtaxa of synonyms too, if requested
    # (don't modify the names_array we're iterating over)
    if args[:include_subtaxa]
      names_array.each do |n|
        # |= don't add duplicates
        name_ids |= Name.subtaxa_of(n).map(&:id)
      end
    end

    # Query, with possible join to Naming. Mutually exclusive options:
    if args[:include_all_name_proposals]
      joins(:namings).where(namings: { name_id: name_ids })
    elsif args[:of_look_alikes]
      joins(:namings).where(namings: { name_id: name_ids }).
        where.not(name: name_ids)
    else
      where(name_id: name_ids)
    end
  }

  scope :of_name_like,
        ->(name) { where(name: Name.text_name_includes(name)) }

  scope :in_clade, lambda { |val|
    if val.is_a?(Name)
      name = val
      text_name = name.text_name
      rank = name.rank
    elsif val.is_a?(String) && (name = Name.best_match(val))
      text_name = name.text_name
      rank = name.rank
    else
      text_name = val
      rank = "Genus"
    end

    if Name.ranks_above_genus.include?(rank)
      where(text_name: text_name).or(
        where(Observation[:classification].matches("%#{rank}: _#{text_name}_%"))
      )
    else
      where(text_name: text_name).or(
        where(Observation[:text_name].matches("#{text_name} %"))
      )
    end
  }

  scope :by_user,
        ->(user) { where(user: user) }
  scope :mappable,
        -> { where.not(location: nil).or(where.not(lat: nil)) }
  scope :unmappable,
        -> { where(location: nil).and(where(lat: nil)) }
  scope :with_location,
        -> { where.not(location: nil) }
  scope :without_location,
        -> { where(location: nil) }
  scope :at_location,
        ->(location) { where(location: location) }
  scope :in_region,
        lambda { |region|
          region = Location.reverse_name_if_necessary(region)
          if Location.understood_continent?(region)
            countries = Location.countries_in_continent(region).join("|")
            where(Observation[:where].matches(", (#{countries})$"))
          else
            where(Observation[:where].matches("%#{region}"))
          end
        }
  scope :in_box, # Use named parameters (n, s, e, w), any order
        lambda { |**args|
          box = Mappable::Box.new(
            north: args[:n], south: args[:s], east: args[:e], west: args[:w]
          )
          return none unless box.valid?

          # resize box by epsilon to create leeway for Float rounding
          # Fixes a bug where Califoria fixture was not in a box
          # defined by the fixture's north, south, east, west
          resized_box = box.expand(0.00001)

          if box.straddles_180_deg?
            where(
              (Observation[:lat] >= resized_box.south).
              and(Observation[:lat] <= resized_box.north).
              and(Observation[:long] >= resized_box.west).
              or(Observation[:long] <= resized_box.east)
            )
          else
            where(
              (Observation[:lat] >= resized_box.south).
              and(Observation[:lat] <= resized_box.north).
              and(Observation[:long] >= resized_box.west).
              and(Observation[:long] <= resized_box.east)
            )
          end
        }
  scope :not_in_box, # Use named parameters (n, s, e, w), any order
        lambda { |**args|
          box = Mappable::Box.new(
            north: args[:n], south: args[:s], east: args[:e], west: args[:w]
          )

          return Observation.all unless box.valid?

          # resize box by epsilon to create leeway for Float rounding
          resized_box = box.expand(-0.00001)

          if box.straddles_180_deg?
            where(
              Observation[:lat].eq(nil).or(Observation[:long].eq(nil)).
              or(Observation[:lat] < resized_box.south).
              or(Observation[:lat] > resized_box.north).
              or((Observation[:long] < resized_box.west).
                 and(Observation[:long] > resized_box.east))
            )
          else
            where(
              Observation[:lat].eq(nil).or(Observation[:long].eq(nil)).
              or(Observation[:lat] < resized_box.south).
              or(Observation[:lat] > resized_box.north).
              or(Observation[:long] < resized_box.west).
              or(Observation[:long] > resized_box.east)
            )
          end
        }

  scope :is_collection_location,
        -> { where(is_collection_location: true) }
  scope :not_collection_location,
        -> { where(is_collection_location: false) }
  scope :with_image,
        -> { where.not(thumb_image: nil) }
  scope :without_image,
        -> { where(thumb_image: nil) }
  scope :with_notes,
        -> { where.not(notes: no_notes) }
  scope :without_notes,
        -> { where(notes: no_notes) }
  scope :has_notes_field,
        ->(field) { where(Observation[:notes].matches("%:#{field}:%")) }
  scope :notes_include,
        ->(notes) { where(Observation[:notes].matches("%#{notes}%")) }
  scope :with_specimen,
        -> { where(specimen: true) }
  scope :without_specimen,
        -> { where(specimen: false) }
  scope :with_sequence,
        -> { joins(:sequences).distinct }
  scope :without_sequence, lambda {
    # much faster than `missing(:sequences)` which uses left outer join.
    where.not(id: with_sequence)
  }
  scope :confidence, lambda { |min, max = min| # confidence between min & max %
    where(vote_cache: (min.to_f / (100 / 3))..(max.to_f / (100 / 3)))
  }
  scope :with_comments,
        -> { joins(:comments).distinct }
  scope :without_comments,
        -> { where.not(id: Observation.with_comments) }
  scope :comments_include, lambda { |summary|
    joins(:comments).where(Comment[:summary].matches("%#{summary}%")).distinct
  }
  scope :for_project, lambda { |project|
    joins(:project_observations).
      where(ProjectObservation[:project_id] == project.id).distinct
  }
  scope :in_herbarium, lambda { |herbarium|
    joins(:herbarium_records).
      where(HerbariumRecord[:herbarium_id] == herbarium.id).distinct
  }
  scope :herbarium_record_notes_include, lambda { |notes|
    joins(:herbarium_records).
      where(HerbariumRecord[:notes].matches("%#{notes}%")).distinct
  }
  scope :on_species_list, lambda { |species_list|
    joins(:species_list_observations).
      where(SpeciesListObservation[:species_list_id] == species_list.id).
      distinct
  }
  scope :on_species_list_of_project, lambda { |project|
    joins(species_lists: :project_species_lists).
      where(ProjectSpeciesList[:project_id] == project.id).distinct
  }
  scope :show_includes, lambda {
    includes(
      :collection_numbers,
      { comments: :user },
      { external_links: { external_site: { project: :user_group } } },
      { herbarium_records: [{ herbarium: :curators }, :user] },
      { images: [:image_votes, :license, :projects, :user] },
      { interests: :user },
      :location,
      :name,
      { namings: [:name, :user, { votes: [:observation, :user] }] },
      { projects: :admin_group },
      :rss_log,
      :sequences,
      { species_lists: [:projects, :user] },
      :thumb_image,
      :user
    )
  }
  scope :not_logged_in_show_includes, lambda {
    strict_loading.includes(
      { comments: :user },
      { images: [:license, :user] },
      :location,
      :name,
      { namings: [:name, :user, { votes: [:observation, :user] }] },
      :projects,
      :thumb_image,
      :user
    )
  }
  scope :naming_includes, lambda {
    includes(
      :herbarium_records, # in case naming is "Imageless"
      :location, # ugh. worth it because of cache_content_filter_data
      :name,
      # Observation#find_matches complains synonym is not eager-loaded. TBD
      { namings: [{ name: { synonym: :names } }, :user,
                  { votes: [:observation, :user] }] },
      :species_lists, # in case naming is "Imageless"
      :user
    )
  }

  def location?
    false
  end

  def observation?
    true
  end

  def can_edit?(user = User.current)
    Project.can_edit?(self, user)
  end

  def project_admin?(user = User.current)
    Project.admin_power?(self, user)
  end

  # There is no value to keeping a collection number record after all its
  # observations are destroyed or removed from it.
  def destroy_orphaned_collection_numbers
    collection_numbers.each do |col_num|
      col_num.destroy_without_callbacks if col_num.observations == [self]
    end
  end

  # Cache location and name data used by content filters.
  def cache_content_filter_data
    if name && name_id_changed?
      self.lifeform = name.lifeform
      self.text_name = name.text_name
      self.classification = name.classification
    end
    self.where = location.name if location && location_id_changed?
  end

  # This is meant to be run nightly to ensure that the cached name
  # and location data used by content filters is kept in sync.
  def self.refresh_content_filter_caches
    refresh_cached_column("name", "lifeform") +
      refresh_cached_column("name", "text_name") +
      refresh_cached_column("name", "classification") +
      refresh_cached_column("location", "name", "where")
  end

  # Refresh a column which is a mirror of a foreign column.  Fixes all the
  # errors, and reports which ids were broken.
  def self.refresh_cached_column(type, foreign, local = foreign)
    tbl = type.camelize.constantize.arel_table
    broken_caches = get_broken_caches(type, tbl, foreign, local)
    broken_caches.map do |id|
      "Fixing #{type} #{foreign} for obs ##{id}."
    end
    # Refresh the mirror of a foreign table's column in the observations table.
    broken_caches.update_all(
      Observation[local.to_sym].eq(tbl[foreign.to_sym]).to_sql
    )
  end

  private_class_method def self.get_broken_caches(type, tbl, foreign, local)
    Observation.joins(type.to_sym).
      where(Observation[local.to_sym].not_eq(tbl[foreign.to_sym]))
  end

  # Used by Name and Location to update the observation cache when a cached
  # field value is changed.
  def self.update_cache(type, field, id, val)
    Observation.where("#{type}_id": id).update_all("#{field}": val)
  end

  # Check for any observations whose consensus is a misspelled name.  This can
  # mess up the mirrors because misspelled names are "invisible", so their
  # classification and lifeform and such will not necessarily be kept up to
  # date.  Fixes and returns a messages for each one that was wrong.
  def self.make_sure_no_observations_are_misspelled
    misspellings = Observation.joins(:name).
                   where(Name[:correct_spelling_id].not_eq(nil))

    misspellings.
      pluck(Observation[:id], Name[:text_name]).map do |id, search_name|
      "Observation ##{id} was misspelled: #{search_name.inspect}"
    end
    misspellings.update_all(
      Observation[:name_id].eq(Name[:correct_spelling_id]).to_sql
    )
  end

  def update_view_stats
    super
    return if User.current.blank?

    @old_last_viewed_by ||= {}
    @old_last_viewed_by[User.current_id] = last_viewed_by(User.current)
    ObservationView.update_view_stats(id, User.current_id)
  end

  def last_viewed_by(user)
    observation_views.find_by(user: user)&.last_view
  end

  def old_last_viewed_by(user)
    @old_last_viewed_by && @old_last_viewed_by[user&.id]
  end

  # This allows Observation to override AR `touch` in this context only,
  # to cache a log_updated_at value
  def touch_when_logging
    self.log_updated_at = Time.zone.now
    save
  end

  ##############################################################################
  #
  #  :section: Location Stuff
  #
  ##############################################################################

  # Abstraction over +where+ and +location.display_name+.  Returns Location
  # name as a string, preferring +location+ over +where+ wherever both exist.
  # Also applies the location_format of the current user (defaults to "postal").
  def place_name
    if location
      location.display_name
    elsif User.current_location_format == "scientific"
      Location.reverse_name(where)
    else
      where
    end
  end

  # Set +where+ or +location+, depending on whether a Location is defined with
  # the given +display_name+.  (Fills the other in with +nil+.)
  # Adjusts for the current user's location_format as well.
  def place_name=(place_name)
    place_name = place_name.strip_squeeze
    where = if User.current_location_format == "scientific"
              Location.reverse_name(place_name)
            else
              place_name
            end
    loc = Location.find_by_name(where)
    if loc
      self.where = loc.name
      self.location = loc
    else
      self.where = where
      self.location = nil
    end
  end

  # Useful for forms in which date is entered in YYYYMMDD format: When form tag
  # helper creates input field, it reads obs.when_str and gets date in
  # YYYYMMDD.  When form submits, assigning string to obs.when_str saves string
  # verbatim in @when_str, and if it is valid, sets the actual when field.
  # When you go to save the observation, it detects invalid format and prevents
  # save.  When it renders form again, it notes the error, populates the input
  # field with the old invalid string for editing, and colors it red.
  def when_str
    @when_str || self.when.strftime("%Y-%m-%d")
  end

  def when_str=(val)
    @when_str = val
    begin
      self.when = val if Date.parse(val)
    rescue ArgumentError
    end
    val
  end

  def lat=(val)
    lat = Location.parse_latitude(val)
    lat = val if lat.nil? && val.present?
    self[:lat] = lat
  end

  def long=(val)
    long = Location.parse_longitude(val)
    long = val if long.nil? && val.present?
    self[:long] = long
  end

  def alt=(val)
    alt = Location.parse_altitude(val)
    alt = val if alt.nil? && val.present?
    self[:alt] = alt
  end

  # Is lat/long more than 10% outside of location extents?
  def lat_long_dubious?
    lat && location && !location.lat_long_close?(lat, long)
  end

  # Alias for access by Mappable::CollapsibleCollectionOfObjects
  # which must provide `lng` for Google Maps from an obs OR a MapSet
  # Makes related methods so much simpler: parallel data types.
  def lng
    long
  end

  def place_name_and_coordinates
    if lat.present? && long.present?
      lat_string = format_coordinate(lat, "N", "S")
      long_string = format_coordinate(long, "E", "W")
      "#{place_name} (#{lat_string} #{long_string})"
    else
      place_name
    end
  end

  # Returns latitude if public or if the current user owns the observation.
  # The user should also be able to see hidden latitudes if they are an admin
  # or they are members of a project that the observation belongs to, but
  # those are harder to determine. This catches the majority of cases.
  def public_lat
    gps_hidden && user_id != User.current_id ? nil : lat
  end

  def public_long
    gps_hidden && user_id != User.current_id ? nil : long
  end

  def reveal_location?
    !gps_hidden || can_edit? || project_admin?
  end

  def display_lat_long
    return "" unless lat

    "#{lat.abs}°#{lat.negative? ? "S" : "N"} " \
      "#{long.abs}°#{long.negative? ? "W" : "E"}"
  end

  def display_alt
    return "" unless alt

    "#{alt.round}m"
  end

  def saved_change_to_place?
    saved_change_to_location_id? || saved_change_to_where?
  end

  ##############################################################################
  #
  #  :section: Notes
  #
  ##############################################################################
  #
  # Notes are arbitrary text supplied by the User.
  # They are read and written as a serialized Hash.
  #
  # The Hash keys are:
  #   - key(s) from the User's notes template, and
  #   - a general Other key supplied by the system.
  #
  # Keys with empty values are not saved.
  #
  # The notes template is a comma-separated list of arbitrary keys (except for
  # the following which are reserved for the system: "Other", "other", etc., and
  # translations thereof.
  # Sample observation.notes
  #  { }                                        no notes
  #  { Other: "rare" }                          generalized notes
  #  { Cap: "red", stem: "white" }              With only user-supplied keys
  #  { Cap: "red", stem: "white", Other: rare } both user-supplied and general
  #
  # The create Observation form displays separate fields for the keys in the
  # following order:
  #   - each key in the notes template, in the order listed in the template; and
  #   - Other.
  #
  # The edit Observation form displays separate fields in the following order:
  #   - each key in the notes template, in the order listed in the template;
  #   - each "orphaned" key -- one which is neither in the template nor Other;
  #   - Other.
  #
  # The show Observation view displays notes as follows, with Other underscored:
  #   no notes - nothing shown
  #   only generalized notes:
  #     Notes: value
  #   only user-supplied keys:
  #     Notes:
  #     First user key: value
  #     Second user key: value
  #     ...
  #   both user-supplied  and general Other keys:
  #     Notes:
  #     First user key: value
  #     Second user key: value
  #     ...
  #     Other: value
  # Because keys with empty values are not saved in observation.notes, they are
  # not displayed with show Observaation.
  #
  # Notes are exported as shown, except that the intial "Notes:" caption is
  # omitted, and any markup is stripped from the keys.

  serialize :notes

  # value of observation.notes if there are no notes
  def self.no_notes
    {}
  end

  # no_notes persisted in the db
  def self.no_notes_persisted
    no_notes.to_yaml
  end

  # Key used for general Observation.notes
  # (notes which were not entered in a notes_template field)
  def self.other_notes_key
    :Other
  end

  # convenience wrapper around class method of same name
  def other_notes_key
    Observation.other_notes_key
  end

  # other_notes_key as a String
  # Makes it easy to combine with notes_template
  def self.other_notes_part
    other_notes_key.to_s
  end

  def other_notes_part
    Observation.other_notes_part
  end

  def other_notes
    notes ? notes[other_notes_key] : nil
  end

  def other_notes=(val)
    self.notes ||= {}
    notes[other_notes_key] = val
  end

  # id of view textarea for a Notes heading. Used in tests
  def self.notes_part_id(part)
    "#{notes_area_id_prefix}#{part.tr(" ", "_")}"
  end

  def notes_part_id(part)
    Observation.notes_part_id(part)
  end

  # prefix for id of textarea
  def self.notes_area_id_prefix
    "observation_notes_"
  end

  # value of notes part
  #   notes: { Other: abc }
  #   observation.notes_part_value("Other") #=> "abc"
  #   observation.notes_part_value(:Other)  #=> "abc"
  def notes_part_value(part)
    notes.blank? ? "" : notes[notes_normalized_key(part)]
  end

  # Change spaces to underscores in keys
  #   notes_normalized_key("Nearby trees") #=> :Nearby_trees
  #   notes_normalized_key(:Other)         #=> :Other
  def notes_normalized_key(part)
    part.to_s.tr(" ", "_").to_sym
  end

  # Array of note parts (Strings) to display in create & edit form,
  # in following (display) order. Used by views.
  #   notes_template fields
  #   orphaned fields (field in obs, but not in notes_template, not "Other")
  #   "Other"
  # Example outputs:
  #   ["Other"]
  #   ["orphaned_part", "Other"]
  #   ["template_1st_part", "template_2nd_part", "Other"]
  #   ["template_1st_part", "template_2nd_part", "orphaned_part", "Other"]
  def form_notes_parts(user)
    return user.notes_template_parts + [other_notes_part] if notes.blank?

    user.notes_template_parts + notes_orphaned_parts(user) +
      [other_notes_part]
  end

  # Array of notes parts (Strings) which are
  # neither in the notes_template nor the caption for other notes
  def notes_orphaned_parts(user)
    return [] if notes.blank?

    # Change spaces to underscores in order to subtract template parts from
    # stringified keys because keys have underscores instead of spaces
    template_parts_underscored = user.notes_template_parts.each do |part|
      part.tr!(" ", "_")
    end
    notes.keys.map(&:to_s) - template_parts_underscored - [other_notes_part]
  end

  # notes as a String, captions (keys) without added formstting,
  # omitting "Other" if it's the only caption.
  #  notes: {}                                 ::=> ""
  #  notes: { Other: "abc" }                   ::=> "abc"
  #  notes: { cap: "red" }                     ::=> "cap: red"
  #  notes: { cap: "red", stem: , Other: "x" } ::=> "cap: red
  #                                                  stem:
  #                                                  Other: x"
  def self.export_formatted(notes, markup = nil)
    return "" if notes.blank?
    return notes[other_notes_key] if notes.keys == [other_notes_key]

    result = notes.each_with_object(+"") do |(key, value), str|
      str << "#{markup}#{key}#{markup}: #{value}\n"
    end
    result.chomp
  end

  # wraps Class method with slightly different name
  def notes_export_formatted
    Observation.export_formatted(notes)
  end

  # Notes (or other hash) as a String, captions (keys) with added formstting,
  # omitting "Other" if it's the only caption.
  #
  # Used in views which display notes
  #  notes: {}                                 => ""
  #  notes: { Other: "abc" }                   => "abc"
  #  notes: { cap: "red" }                     => "+cap+: red"
  #  notes: { cap: "red", stem: , other: "x" } => "+cap+: red
  #                                                +stem+:
  #                                                +Other+: x"
  def self.show_formatted(notes)
    export_formatted(notes, "+")
  end

  # wraps Class method with slightly different name
  def notes_show_formatted
    Observation.show_formatted(notes)
  end

  ##############################################################################
  #
  #  :section: Name Formats
  #
  ##############################################################################

  # Name in plain text with id to make it unique, never nil.
  def unique_text_name
    string_with_id(name.real_search_name)
  end

  # Textile-marked-up name, never nil.
  def format_name
    name.observation_name
  end

  # Textile-marked-up name with id to make it unique, never nil.
  def unique_format_name
    string_with_id(name.observation_name)
  rescue StandardError
    ""
  end

  ##############################################################################
  #
  #  :section: Namings and Votes
  #
  ##############################################################################

  # Look up the corresponding instance in our namings association.  If we are
  # careful to keep all the operations within the tree of assocations of the
  # observations, we should never need to reload anything.
  # `find` here does not hit the db
  def lookup_naming(naming)
    # Disable cop; test suite chokes when the following "raise"
    # is re-written in "exploded" style (the Rubocop default)
    # rubocop:disable Style/RaiseArgs
    namings.find { |n| n == naming } ||
      raise(ActiveRecord::RecordNotFound,
            "Observation doesn't have naming with ID=#{naming.id}")
    # rubocop:enable Style/RaiseArgs
  end

  # Dump out the situation as the observation sees it.  Useful for debugging
  # problems with reloading requirements.
  def dump_votes
    namings.map do |n|
      str = "#{n.id} #{n.name.real_search_name}: "
      if n.votes.empty?
        str += "no votes"
      else
        votes = n.votes.map do |v|
          "#{v.user.login}=#{v.value}" + (v.favorite ? "(*)" : "")
        end
        str += votes.join(", ")
      end
      str
    end.join("\n")
  end

  # Has anyone proposed a given Name yet for this observation?
  # Count is ok here because we have eager-loaded the namings.
  def name_been_proposed?(name)
    namings.any? { |n| n.name == name }
  end

  # Has the owner voted on a given Naming?
  def owner_voted?(naming)
    !lookup_naming(naming).users_vote(user).nil?
  end

  # Has a given User owner voted on a given Naming?
  def user_voted?(naming, user)
    !lookup_naming(naming).users_vote(user).nil?
  end

  # Get the owner's Vote on a given Naming.
  def owners_vote(naming)
    lookup_naming(naming).users_vote(user)
  end

  # Get a given User's Vote on a given Naming.
  def users_vote(naming, user)
    lookup_naming(naming).users_vote(user)
  end

  # Disable method name cops to avoid breaking 3rd parties' use of API

  # Returns true if a given Naming has received one of the highest positive
  # votes from the owner of this observation.
  # Note: multiple namings can return true for a given observation.
  # This is used to display eyes next to Proposed Name on Observation page
  def owners_favorite?(naming)
    lookup_naming(naming).users_favorite?(user)
  end

  # Returns true if a given Naming has received one of the highest positive
  # votes from the given user (among namings for this observation).
  # Note: multiple namings can return true for a given user and observation.
  def users_favorite?(naming, user)
    lookup_naming(naming).users_favorite?(user)
  end

  # All of observation.user's votes on all Namings for this Observation
  # Used in Observation and in tests
  def owners_votes
    user_votes(user)
  end

  # All of a given User's votes on all Namings for this Observation
  def user_votes(user)
    namings.each_with_object([]) do |n, votes|
      v = n.users_vote(user)
      votes << v if v
    end
  end

  # Change User's Vote for this naming.  Automatically recalculates the
  # consensus for the Observation in question if anything is changed.  Returns
  # true if something was changed.
  def change_vote(naming, value, user = User.current)
    result = false
    naming = lookup_naming(naming)
    vote = naming.users_vote(user)
    value = value.to_f

    if value == Vote.delete_vote
      result = delete_vote(naming, vote, user)

    # If no existing vote, or if changing value.
    elsif !vote || (vote.value != value)
      result = true
      process_real_vote(naming, vote, value, user)
    end

    # Update consensus if anything changed.
    calc_consensus if result

    result
  end

  def change_vote_with_log(naming, vote)
    reload
    change_vote(naming, vote.value, naming.user)
    log(:log_naming_created, name: naming.format_name)
  end

  # Try to guess which Naming is responsible for the consensus.  This will
  # always return a Naming, no matter how ambiguous, unless there are no
  # namings.
  def consensus_naming
    matches = find_matches
    return nil if matches.empty?
    return matches.first if matches.length == 1

    best_naming = matches.first
    best_value = matches.first.vote_cache
    matches.each do |naming|
      next unless naming.vote_cache > best_value

      best_naming = naming
      best_value = naming.vote_cache
    end
    best_naming
  end

  def calc_consensus
    reload
    calculator = Observation::ConsensusCalculator.new(namings)
    best, best_val = calculator.calc
    old = name
    if name != best || vote_cache != best_val
      self.name = best
      self.vote_cache = best_val
      save
    end
    announce_consensus_change(old, best) if best != old
  end

  # Admin tool that refreshes the vote cache for all observations with a vote.
  def self.refresh_vote_cache
    Observation.find_each(&:calc_consensus)
  end

  private

  def find_matches
    matches = namings.select { |n| n.name_id == name_id }
    return matches unless matches == [] && name && name.synonym_id

    namings.select { |n| name.synonyms.include?(n.name) }
  end

  def format_coordinate(value, positive_point, negative_point)
    return "#{-value.round(4)}°#{negative_point}" if value.negative?

    "#{value.round(4)}°#{positive_point}"
  end

  def delete_vote(naming, vote, user)
    return false unless vote

    naming.votes.delete(vote)
    find_new_favorite(user) if vote.favorite
    true
  end

  def find_new_favorite(user)
    max = max_positive_vote(user)
    return unless max.positive?

    user_votes(user).each do |v|
      next if v.value != max || v.favorite

      v.favorite = true
      v.save
    end
  end

  def max_positive_vote(user)
    max = 0
    user_votes(user).each do |v|
      max = v.value if v.value > max
    end
    max
  end

  def process_real_vote(naming, vote, value, user)
    downgrade_totally_confident_votes(value, user)
    favorite = adjust_other_favorites(value, other_votes(vote, user))
    if vote
      vote.value = value
      vote.favorite = favorite
      vote.save
    else
      naming.votes.create!(
        user: user,
        observation: self,
        value: value,
        favorite: favorite
      )
    end
  end

  def downgrade_totally_confident_votes(value, user)
    # First downgrade any existing 100% votes (if casting a 100% vote).
    v80 = Vote.next_best_vote
    return if value <= v80

    user_votes(user).each do |v|
      next unless v.value > v80

      v.value = v80
      v.save
    end
  end

  def adjust_other_favorites(value, other_votes)
    favorite = false
    if value.positive?
      favorite = true
      other_votes.each do |v|
        if v.value > value
          favorite = false
          break
        end
        if (v.value < value) && v.favorite
          v.favorite = false
          v.save
        end
      end
    end

    # Will any other vote become a favorite?
    max_positive_value = (other_votes.map(&:value) + [value, 0]).max
    other_votes.each do |v|
      if (v.value >= max_positive_value) && !v.favorite
        v.favorite = true
        v.save
      end
    end
    favorite
  end

  def other_votes(vote, user)
    user_votes(user) - [vote]
  end

  public

  ##############################################################################
  #
  #  :section: Images
  #
  ##############################################################################

  # Add Image to this Observation, making it the thumbnail if none set already.
  # Saves changes.  Returns Image.
  def add_image(img)
    unless images.include?(img)
      images << img
      self.thumb_image = img unless thumb_image
      self.updated_at = Time.zone.now
      save
      notify_users(:added_image)
      reload
    end
    img
  end

  # Removes an Image from this Observation.  If it's the thumbnail, changes
  # thumbnail to next available Image.  Saves change to thumbnail, might save
  # change to Image.  Returns Image.
  def remove_image(img)
    if images.include?(img) || thumb_image_id == img.id
      images.delete(img)
      update(thumb_image: images.empty? ? nil : images.first) \
        if thumb_image_id == img.id
      notify_users(:removed_image)
    end
    img
  end

  # Determines if an obs can have the Naming "_Imageless_"
  # N+1: maybe move method to NamingConsensus and
  # Add species_lists and herbarium_records to naming_includes
  def has_backup_data?
    !thumb_image_id.nil? ||
      species_lists.count.positive? ||
      herbarium_records.count.positive? ||
      specimen ||
      notes.length >= 100
  end

  ##############################################################################
  #
  #  :section: Specimens
  #
  ##############################################################################

  def turn_off_specimen_if_no_more_records
    return unless specimen
    return unless collection_numbers.empty?
    return unless herbarium_records.empty?
    return unless sequences.empty?

    update(specimen: false)
  end

  # Return primary collector and their number if available, else just return
  # the observer's name.
  def collector_and_number
    return user.legal_name if collection_numbers.empty?

    collection_numbers.first.format_name
  end

  ##############################################################################
  #
  #  :section: Sources
  #
  ##############################################################################

  # Which agent created this observation?
  enum source:
        {
          mo_website: 1,
          mo_android_app: 2,
          mo_iphone_app: 3,
          mo_api: 4
        }

  # Message to use to credit the agent which created this observation.
  # Intended to be used with .tpl to render as HTML:
  #   <%= observation.source_credit.tpl %>
  def source_credit
    :"source_credit_#{source}" if source.present?
  end

  # Do we want to prominantly advertise the source of this observation?
  def source_noteworthy?
    source.present? && source != "mo_website"
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Callback that updates a User's contribution after adding an Observation to
  # a SpeciesList.
  def add_spl_callback(_obs)
    SiteData.update_contribution(:add, :species_list_entries, user_id)
  end

  # Callback that updates a User's contribution after removing an Observation
  # from a SpeciesList.
  def remove_spl_callback(_obs)
    SiteData.update_contribution(:del, :species_list_entries, user_id)
  end

  # Callback that logs an Observation's destruction on all of its
  # SpeciesList's.  (Also saves list of Namings so they can be destroyed
  # by hand afterword without causing superfluous calc_consensuses.)
  def notify_species_lists
    # Tell all the species lists it belonged to.
    species_lists.each do |spl|
      spl.log(:log_observation_destroyed2, name: unique_format_name,
                                           touch: false)
    end

    # Save namings so we can delete them after it's dead.
    @old_namings = namings
  end

  # Callback that destroys an Observation's Naming's (carefully) after the
  # Observation is destroyed.
  def destroy_dependents
    @old_namings.each do |naming|
      naming.observation = nil # (tells it not to recalc consensus)
      naming.destroy
    end
  end

  # Callback that sends email notifications after save.
  def notify_users_after_change
    if !id ||
       saved_change_to_when? ||
       saved_change_to_where? ||
       saved_change_to_location_id? ||
       saved_change_to_notes? ||
       saved_change_to_specimen? ||
       saved_change_to_is_collection_location? ||
       saved_change_to_thumb_image_id?
      notify_users(:change)
    end
  end

  # Callback that sends email notifications after destroy.
  def notify_users_before_destroy
    notify_users(:destroy)
  end

  # Send email notifications upon change to Observation.  Several actions are
  # possible:
  #
  # added_image::   Image was added.
  # removed_image:: Image was removed.
  # change::        Other changes (e.g. to notes).
  # destroy::       Observation destroyed.
  #
  #   obs.images << Image.create
  #   obs.notify_users(:added_image)
  #
  def notify_users(action)
    sender = user
    recipients = []

    # Send to people who have registered interest.
    interests.each do |interest|
      recipients.push(interest.user) if interest.state
    end

    # Tell masochists who want to know about all observation changes.
    User.where(email_observations_all: true).find_each do |user|
      recipients.push(user)
    end

    # Send notification to all except the person who triggered the change.
    recipients.uniq.each do |recipient|
      next if !recipient || recipient == sender || recipient.no_emails

      case action
      when :destroy
        QueuedEmail::ObservationChange.destroy_observation(sender, recipient,
                                                           self)
      when :change
        QueuedEmail::ObservationChange.change_observation(sender, recipient,
                                                          self)
      else
        QueuedEmail::ObservationChange.change_images(sender, recipient, self,
                                                     action)
      end
    end
  end

  # Send email notifications upon change to consensus.
  #
  #   old_name = obs.name
  #   obs.name = new_name
  #   obs.announce_consensus_change(old_name, new_name)
  #
  def announce_consensus_change(old_name, new_name)
    log_consensus_change(old_name, new_name)

    # Change can trigger emails.
    owner  = user
    sender = User.current
    recipients = []

    # Tell owner of observation if they want.
    recipients.push(owner) if owner&.email_observations_consensus

    # Send to people who have registered interest.
    # Also remove everyone who has explicitly said they are NOT interested.
    interests.each do |interest|
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end

    # Remove users who have opted out of all emails.
    recipients.reject!(&:no_emails)

    # Send notification to all except the person who triggered the change.
    (recipients.uniq - [sender]).each do |recipient|
      QueuedEmail::ConsensusChange.create_email(sender, recipient, self,
                                                old_name, new_name)
    end
  end

  def log_consensus_change(old_name, new_name)
    if old_name
      log(:log_consensus_changed, old: old_name.display_name,
                                  new: new_name.display_name)
    else
      log(:log_consensus_created, name: new_name.display_name)
    end
  end

  # After defining a location, update any lists using old "where" name.
  def self.define_a_location(location, old_name)
    old_name = connection.quote(old_name)
    new_name = connection.quote(location.name)
    connection.update(%(
      UPDATE observations
      SET `where` = #{new_name}, location_id = #{location.id}
      WHERE `where` = #{old_name}
    ))
  end

  ##############################################################################

  protected

  include Validations # currently only `validate_when`

  validate :check_requirements, :check_when

  def check_requirements
    check_where
    check_user
    check_coordinates

    return unless @when_str

    begin
      Date.parse(@when_str)
    rescue ArgumentError
      if /^\d{4}-\d{1,2}-\d{1,2}$/.match?(@when_str)
        errors.add(:when_str, :runtime_date_invalid.t)
      else
        errors.add(:when_str, :runtime_date_should_be_yyyymmdd.t)
      end
    end
  end

  def check_where
    # Clean off leading/trailing whitespace from +where+.
    self.where = where.strip_squeeze if where
    self.where = nil if where == ""

    if where.to_s.blank? && !location_id
      self.location = Location.unknown
      # errors.add(:where, :validate_observation_where_missing.t)
    elsif where.to_s.size > 1024
      errors.add(:where, :validate_observation_where_too_long.t)
    end
  end

  def check_user
    return if user || User.current

    errors.add(:user, :validate_observation_user_missing.t)
  end

  def check_coordinates
    check_latitude
    check_longitude
    check_altitude
  end

  def check_latitude
    if lat.blank? && long.present? ||
       lat.present? && !Location.parse_latitude(lat)
      errors.add(:lat, :runtime_lat_long_error.t)
    end
  end

  def check_longitude
    if lat.present? && long.blank? ||
       long.present? && !Location.parse_longitude(long)
      errors.add(:long, :runtime_lat_long_error.t)
    end
  end

  def check_altitude
    return unless alt.present? && !Location.parse_altitude(alt)

    # As of July 5, 2020 this statement appears to be unreachable
    # because .to_i returns 0 for unparsable strings.
    errors.add(:alt, :runtime_altitude_error.t)
  end

  def check_when
    self.when ||= Time.zone.now
    validate_when(self.when, errors)
  end
end
