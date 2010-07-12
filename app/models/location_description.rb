#
#  = Location Descriptions
#
#  == Version
#
#  Changes are kept in the "location_descriptions_versions" table using
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
#  merge_source_id::  (V) Used to keep track of descriptions that were merged into this one.
#                         Primarily useful in the past versions: stores id of latest version
#                         of the Description merged into this one at the time of the merge.
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
#  location_descriptions_versions table.)
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
  belongs_to :license
  belongs_to :location
  belongs_to :project
  belongs_to :user

  has_many :comments,  :as => :object, :dependent => :destroy
  has_many :interests, :as => :object, :dependent => :destroy

  has_and_belongs_to_many :admin_groups,  :class_name => "UserGroup", :join_table => "location_descriptions_admins"
  has_and_belongs_to_many :writer_groups, :class_name => "UserGroup", :join_table => "location_descriptions_writers"
  has_and_belongs_to_many :reader_groups, :class_name => "UserGroup", :join_table => "location_descriptions_readers"
  has_and_belongs_to_many :authors,       :class_name => "User",      :join_table => "location_descriptions_authors"
  has_and_belongs_to_many :editors,       :class_name => "User",      :join_table => "location_descriptions_editors"

  ALL_NOTE_FIELDS = [ :gen_desc, :ecology, :species, :notes, :refs ]

  acts_as_versioned(
    :table_name => 'location_descriptions_versions',
    :if_changed => ALL_NOTE_FIELDS,
    :association_options => { :dependent => :orphan }
  )
  non_versioned_columns.push(
    'sync_id',
    'created',
    'location_id',
    'num_views',
    'last_view',
    'ok_for_export',
    'source_type',
    'source_name',
    'project_id',
    'public',
    'locale'
  )

  versioned_class.before_save {|x| x.user_id = User.current_id}
  after_update :notify_users

  ################################################################################
  #
  #  :section: Descriptions
  #
  ################################################################################

  # Returns an Array of all the descriptive text fields (Symbol's).
  def self.all_note_fields
    ALL_NOTE_FIELDS
  end

  # This is called after saving potential changes to a Location.  It will
  # determine if the changes are important enough to notify people, and do so. 
  def notify_users

    # "altered?" is acts_as_versioned's equivalent to Rails's changed? method.
    # It only returns true if *important* changes have been made.
    if altered?
      sender = User.current
      recipients = []

      # Tell admins of the change.
      for user in self.admins
        recipients.push(user) if user.email_locations_admin
      end

      # Tell authors of the change.
      for user in self.authors
        recipients.push(user) if user.email_locations_author
      end

      # Tell editors of the change.
      for user in self.editors
        recipients.push(user) if user.email_locations_editor
      end

      # Tell masochists who want to know about all location changes.
      for user in User.find_all_by_email_locations_all(true)
        recipients.push(user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in location.interests
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send notification to all except the person who triggered the change.
      for recipient in recipients.uniq - [sender]
        if recipient.created_here
          QueuedEmail::LocationChange.create_email(sender, recipient, location, self)
        end
      end
    end
  end
end
