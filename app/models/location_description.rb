# frozen_string_literal: true

#
#  = Location Descriptions
#
#  == Version
#
#  Changes are kept in the "location_description_versions" table using
#  ActiveRecord::Acts::Versioned.
#
#  == Attributes
#
#  id::               (-) Locally unique numerical id, starting at 1.
#  created_at::       (-) Date/time it was first created.
#  updated_at::       (V) Date/time it was last updated.
#  user::             (V) User that created it.
#  version::          (V) Version number.
#
#  ==== Statistics
#  num_views::        (-) Number of times it has been viewed.
#  last_view::        (-) Last time it was viewed.
#
#  ==== Description Fields
#  license::          (V) License description info is kept under.
#  gen_desc::         (V) General description of geographic location.
#  ecology::          (V) Description of climate, geology, habitat, etc.
#  species::          (V) Notes on dominant or otherwise interesting species.
#  notes::            (V) Other notes.
#  refs::             (V) References
#
#  ('V' indicates that this attribute is versioned in
#  location_description_versions table.)
#
#  == Class Methods
#
#  all_note_fields::     NameDescriptive text fields: all.
#
#  == Instance Methods
#
#  versions::            Old versions.
#  comments::            Comments about this NameDescription. (not used yet)
#  interests::           Interest in this NameDescription
#
#  == Callbacks
#
#  notify_users::       Notify authors, etc. of changes.
#
############################################################################

class LocationDescription < Description
  require("acts_as_versioned")

  include Description::Scopes

  # Do not change the integer associated with a value
  enum :source_type,
       { public: 1, foreign: 2, project: 3, source: 4, user: 5 },
       suffix: :source, instance_methods: false

  belongs_to :license
  belongs_to :location
  belongs_to :project
  belongs_to :user

  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target

  has_many :location_description_admins, dependent: :destroy
  has_many :admin_groups, through: :location_description_admins,
                          source: :user_group

  has_many :location_description_writers, dependent: :destroy
  has_many :writer_groups, through: :location_description_writers,
                           source: :user_group

  has_many :location_description_readers, dependent: :destroy
  has_many :reader_groups, through: :location_description_readers,
                           source: :user_group

  has_many :location_description_authors, dependent: :destroy
  has_many :authors, through: :location_description_authors,
                     source: :user

  has_many :location_description_editors, dependent: :destroy
  has_many :editors, through: :location_description_editors,
                     source: :user

  scope :order_by_default,
        -> { order_by(::Query::LocationDescriptions.default_order) }

  scope :is_public, lambda { |bool = true|
    where(public: bool)
  }
  scope :by_author, lambda { |user|
    ids = lookup_users_by_name(user)
    joins(:location_description_authors).distinct.
      where(location_description_authors: { user_id: ids })
  }
  scope :by_editor, lambda { |user|
    ids = lookup_users_by_name(user)
    joins(:location_description_editors).distinct.
      where(location_description_editors: { user_id: ids })
  }
  scope :locations, lambda { |loc|
    ids = lookup_locations_by_name(loc)
    where(location: ids)
  }

  scope :location_query, lambda { |hash|
    joins(:location).subquery(:Location, hash)
  }

  scope :show_includes, lambda {
    strict_loading.includes(
      :authors,
      { comments: :user },
      :editors,
      :interests,
      { location: [:descriptions, :interests, :rss_log] },
      :project,
      :user,
      :versions
    )
  }

  ALL_NOTE_FIELDS = [:gen_desc, :ecology, :species, :notes, :refs].freeze
  SEARCHABLE_FIELDS = ALL_NOTE_FIELDS

  acts_as_versioned(
    if_changed: ALL_NOTE_FIELDS,
    association_options: { dependent: :nullify }
  )
  non_versioned_columns.push(
    "created_at",
    "updated_at",
    "location_id",
    "num_views",
    "last_view",
    "ok_for_export",
    "source_type",
    "source_name",
    "project_id",
    "public",
    "locale"
  )

  versioned_class.before_save { |x| x.user_id = User.current_id }
  after_update :notify_users

  ##############################################################################
  #
  #  :section: Descriptions
  #
  ##############################################################################
  def self.show_controller
    # Not the generated default in AbstractModel, because controller namespaced.
    "/locations/descriptions"
  end

  # Returns an Array of all the descriptive text fields (Symbol's).
  def self.all_note_fields
    ALL_NOTE_FIELDS
  end

  # This is called after saving potential changes to a Location.  It will
  # determine if the changes are important enough to notify people, and do so.
  def notify_users
    return unless saved_version_changes?

    sender = User.current
    recipients = []

    # Tell admins of the change.
    admins.each do |user|
      recipients.push(user) if user.email_locations_admin
    end

    # Tell authors of the change.
    authors.each do |user|
      recipients.push(user) if user.email_locations_author
    end

    # Tell editors of the change.
    editors.each do |user|
      recipients.push(user) if user.email_locations_editor
    end

    # Send to people who have registered interest.
    # Also remove everyone who has explicitly said they are NOT interested.
    location.interests.each do |interest|
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
      QueuedEmail::LocationChange.create_email(
        sender, recipient, location, self
      )
    end
  end
end
