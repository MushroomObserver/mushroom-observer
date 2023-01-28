# frozen_string_literal: true

#
#  = Name Descriptions
#
#  == Version
#
#  Changes are kept in the "name_descriptions_versions" table using
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
#  review_status::    (-) "vetted", "unvetted", "inaccurate", "unreviewed".
#  last_review::      (-) Last time it was reviewed.
#  reviewer::         (-) User that reviewed it.
#  ok_for_export::    (-) Boolean: is this ready for export to EOL?
#  num_views::        (-) Number of times it has been viewed.
#  last_view::        (-) Last time it was viewed.
#
#  ==== Description Fields
#  license::          (V) License description info is kept under.
#  classification::   (V) Taxonomic classification.
#  gen_desc::         (V) General description.
#  diag_desc::        (V) Diagnostic description.
#  distribution::     (V) Distribution.
#  habitat::          (V) Habitat.
#  look_alikes::      (V) Look-alikes.
#  uses::             (V) Uses.
#  notes::            (V) Other notes.
#  refs::             (V) References
#
#  ('V' indicates that this attribute is versioned in
#  name_descriptions_versions table.)
#
#  == Class Methods
#
#  all_note_fields::     NameDescriptive text fields: all.
#  eol_note_fields::     NameDescriptive text fields:
#                        ones that don't require special handling for EOL.
#  all_review_statuses:: Review status: allowed values.
#
#  == Instance Methods
#
#  ==== Attachments
#  versions::            Old versions.
#  comments::            Comments about this NameDescription. (not used yet)
#  interests::           Interest in this NameDescription
#
#  ==== Review Status
#  update_review_status:: Change review status.
#
#  == Callbacks
#
#  notify_users::       Notify authors, etc. of changes.
#
############################################################################

class NameDescription < Description
  require "acts_as_versioned"

  # enum definitions for use by simple_enum gem
  # Do not change the integer associated with a value
  enum review_status:
        {
          unreviewed: 1,
          unvetted: 2,
          vetted: 3,
          inaccurate: 4
        }
  enum source_type:
        {
          public: 1,
          foreign: 2,
          project: 3,
          source: 4,
          user: 5
        }, _suffix: :source
  belongs_to :license
  belongs_to :name
  belongs_to :project
  belongs_to :reviewer, class_name: "User"
  belongs_to :user

  has_many :comments,  as: :target, dependent: :destroy, inverse_of: :target
  has_many :interests, as: :target, dependent: :destroy, inverse_of: :target

  has_many :name_description_admins, dependent: :destroy
  has_many :admin_groups, through: :name_description_admins,
                          source: :user_group

  has_many :name_description_writers, dependent: :destroy
  has_many :writer_groups, through: :name_description_writers,
                           source: :user_group

  has_many :name_description_readers, dependent: :destroy
  has_many :reader_groups, through: :name_description_readers,
                           source: :user_group

  has_many :name_description_authors, dependent: :destroy
  has_many :authors, through: :name_description_authors,
                     source: :user

  has_many :name_description_editors, dependent: :destroy
  has_many :editors, through: :name_description_editors,
                     source: :user

  scope :for_eol_export,
        lambda {
          where(review_status: review_statuses.values_at(
            "unvetted", "vetted"
          )).
            where(NameDescription[:gen_desc].not_blank).
            where(ok_for_export: true).
            where(public: true)
        }

  EOL_NOTE_FIELDS = [
    :gen_desc, :diag_desc, :distribution, :habitat, :look_alikes, :uses
  ].freeze
  ALL_NOTE_FIELDS = (
    [:classification] + EOL_NOTE_FIELDS + [:refs, :notes]
  ).freeze

  acts_as_versioned(
    table_name: "name_descriptions_versions",
    if_changed: ALL_NOTE_FIELDS,
    association_options: { dependent: :nullify }
  )
  non_versioned_columns.push(
    "created_at",
    "updated_at",
    "name_id",
    "review_status",
    "last_review",
    "reviewer_id",
    "ok_for_export",
    "num_views",
    "last_view",
    "source_type",
    "source_name",
    "project_id",
    "public",
    "locale"
  )

  versioned_class.before_save { |x| x.user_id = User.current_id }
  after_update :notify_users
  after_save :update_classification_cache

  # Don't add any authors until someone has written something "useful".
  def author_worthy?
    gen_desc.present? || diag_desc.present?
  end

  ##############################################################################
  #
  #  :section: Descriptions
  #
  ##############################################################################
  def self.show_controller
    # Not the generated default in AbstractModel, because controller namespaced.
    "/names/descriptions"
  end

  # Eliminate when controller_normalized? goes.
  def self.show_action
    :show
  end

  # Returns an Array of all the descriptive text fields that don't require any
  # special processing when they go to EOL.  Fields are all Symbol's.
  def self.eol_note_fields
    # These fields all get handled the same way when they go to EOL
    EOL_NOTE_FIELDS
  end

  # Returns an Array of all the descriptive text fields (Symbol's).
  #
  # *NOTE*: :references behave differently for EOL output and :notes get
  # ignored altogether.  Order is important for UI layout.
  #
  def self.all_note_fields
    ALL_NOTE_FIELDS
  end

  ##############################################################################
  #
  #  :section: Reviewing
  #
  ##############################################################################

  # Returns an Array of all possible values for +review_status+ (Symbol's).
  def self.all_review_statuses
    review_statuses.map do |name, _integer|
      name
    end
  end

  # Update the review status.  Saves the changes if there are no substantive
  # changes pending.  (Don't want to inadvertantly create multiple past_name
  # versions.)  Raises a RuntimeError if it fails to save for some reason.
  #
  # Note on permissions: Only reviewers can set the value to anything other
  # than :unreviewed.  The only way for this method to be called by a
  # non-reviewer is if a non-reviewer publishes a draft.  Note, the review
  # status can also get reset back to :unreviewed by edit_name in
  # name_controller if a non-reviewer makes any substantive change to the Name.
  #
  def update_review_status(value)
    user = User.current
    if user.in_group?("reviewers")
      reviewer_id = user.id
    else
      # This communicates the name of the old reviewer to notify_authors.
      # This allows it to notify the old reviewer of the change.
      @old_reviewer = reviewer
      value = :unreviewed
      reviewer_id = nil
    end
    self.review_status = value
    self.reviewer_id   = reviewer_id
    self.last_review   = Time.zone.now

    # Save unless there are substantive changes pending.
    return if save_version?

    save_without_our_callbacks
    raise("update_review_status failed: [#{dump_errors}]") unless errors.empty?
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Make sure the classification cached in Name is kept up to date.
  def update_classification_cache
    if (name.description_id == id) &&
       (name.classification != classification)
      name.update(classification: classification)
      name.propagate_classification if name.rank == "Genus"
    end
  end

  # This is called after saving potential changes to a Name.  It will determine
  # if the changes are important enough to notify the authors, and do so.
  def notify_users
    # Even though
    # changing review_status doesn't cause a new version to be created, I want
    # to notify authors of that change.
    # (saved_change_to_<attribute>? is a Rails automagical method)
    if saved_version_changes? || saved_change_to_review_status?
      sender = User.current || User.admin
      recipients = []

      # Tell admins of the change.
      admins.each do |user|
        recipients.push(user) if user.email_names_admin
      end

      # Tell authors of the change.
      authors.each do |user|
        recipients.push(user) if user.email_names_author
      end

      # Tell editors of the change.
      editors.each do |user|
        recipients.push(user) if user.email_names_editor
      end

      # Tell reviewer of the change.
      reviewer = self.reviewer || @old_reviewer
      recipients.push(reviewer) if reviewer&.email_names_reviewer

      # Tell masochists who want to know about all name changes.
      User.where(email_names_all: true).find_each do |user|
        recipients.push(user)
      end

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      name.interests.each do |interest|
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
        QueuedEmail::NameChange.create_email(sender, recipient, name, self,
                                             saved_change_to_review_status?)
      end
    end

    # No longer need this.
    @old_reviewer = nil
  end

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    self.classification = Name.validate_classification(parent.rank,
                                                       classification)
  rescue StandardError => e
    errors.add(:classification, e.to_s)
  end
end
