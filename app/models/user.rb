# frozen_string_literal: true

#
#  = User Model
#
#  Model describing a User.
#
#  Login is handled by lib/login_system.rb, a third-party package that we've
#  updated slightly.  It is enforced by adding <tt>before_action
#  :login_required</tt> filters to the controllers.
#
#  We now support autologin or "remember me" login via a simple cookie and the
#  application-wide <tt>before_action :autologin</tt> filter in
#  ApplicationController.
#
#  == Signup / Login Process
#
#  Only part of this site is available to anonymous guests.  Sign-up is a
#  two-step process, requiring email verification before the new User can log
#  in.  The full process is as follows:
#
#  1. Anonymous User pokes around until they try to post a Comment, say.  This
#     page requires a login (via +login_required+ filter in controller, see
#     below).  This causes the User to be redirected to /account/login/new.
#
#  2. If the User already has an account, they login here, and wind up
#     redirected back to the form that triggered the login.
#
#  3. If the User has no account, they click on "Create a new account" and go
#     to <tt>/account/signup</tt>.  They fill out the form and submit it.  This
#     creates a new User record, but this record is still unverified (verified
#     is +nil+).
#
#  4. A verification email is sent to the email address given in the sign-up
#     form.  Inside the email is a link to /account/verify.  This provides
#     the User +id+ and +auth_code+.
#
#  5. When they click on that link, the User record is updated and the User is
#     automatically logged in.
#
#  == ApplicationController Filters
#
#  The execution flow for an HTTP request as affects login, including all
#  application-wide filters, is as follows:
#
#  1. +autologin+: Check if User is logged in by first looking at session, then
#     autologin cookie.  Requires User be verified.  Stores User in session,
#     cookie, User#current, and +@user+ (visible to controllers and views).
#     Sets all these to nil if no User logged in.
#
#  2. +set_locale+: Check if User has chosen a locale.
#
#  3. +set_timezone+: Set timezone from cookie set by client's browser.
#
#  4. +login_required+: (optional) Redirects to /account/login/new if not
#     logged in.
#
#  == Contribution Score
#
#  Contribution score is just a cache.  It is very carefully kept up to date by
#  several callbacks in Model and a few other Model subclasses that modify the
#  score every time a User creates, edits or destroys an object.  It is also
#  automatically refreshed whenever anyone views the User's summary page, just
#  in case the callbacks ever fail.
#
#  == Admin Mode
#
#  Any User can be granted administrator privileges.  However, we don't want
#  admins wandering around the site in "admin mode" during every-day usage.
#  Thus we additionally require that admin User's also turn on admin mode.
#  (There's a handy switch in the left-hand column of every page.)  This state
#  is stored in the session.  (See ApplicationController#in_admin_mode?)
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  created_at::         Date/time it was first created.
#  updated_at::         Date/time it was last updated.
#  verified::           Date/time the account was verified.
#  last_login::         Date/time the user last logged in.
#  last_activity::      Date/time the user made last request (updated hourly).
#  blocked::            Boolean: user blocked or deleted?
#
#  ==== Administrative
#  login::              Login name (must be locally unique).
#  name::               Full name.
#  password::           Hashed password.
#  email::              Email address.
#  admin::              Allowed to enter admin mode?
#  alert::              Alert message we need to display for User. (serialized)
#  bonuses::            List of zero or more contribution bonuses. (serialized)
#  contribution::       Contribution score (integer).
#
#  ==== Profile
#  mailing_address::    Mailing address used in naming_for_observer emails.
#  notes::              Free-form Textile notes (provided by User).
#  location::           Primary location (chosen by User).
#  image::              Mug-shot Image.
#  license::            Default license for Images this User uploads.
#
#  ==== Preferences
#  locale::             Language, e.g.: "en" or "pt"
#  theme::              CSS theme, e.g.: "Amanita" or +nil+ for random
#  layout_count::       Number of thumbnails to show in index.
#  notes_template::     Comma separated list of subfields for Observation Notes
#  view_owner_id::      View Observation author's ID on Obs page
#
#  ==== Content filter options
#  content_filter::     Serialized Hash of ContentFilter parameters.
#
#  ==== Email options
#  Send notifications if...
#  email_comments_owner::         ...someone comments on object I own.
#  email_comments_response::      ...someone responds to my Comment.
#  email_comments_all::           ...anyone comments on anything.
#  email_observations_consensus:: ...consensus changes on my Observation.
#  email_observations_naming::    ...someone proposes a Name for my Observation.
#  email_observations_all::       ...anyone changes an Observation.
#  email_names_author::           ...someone changes a Name I've authored.
#  email_names_editor::           ...someone changes a Name I've edited.
#  email_names_reviewer::         ...someone changes a Name I've reviewed.
#  email_names_all::              ...anyone changes a Name.
#  email_locations_author::       ...someone changes a Location I've authored.
#  email_locations_editor::       ...someone changes a Location I've edited.
#  email_locations_all::          ...anyone changes a Location.
#  email_general_feature::        ...you announce new features.
#  email_general_commercial::     ...someone sends me a commercial inquiry.
#  email_general_question::       ...someone sends me a general question.
#  email_digest::                 (not used yet)
#  email_html::                   Send HTML-formatted email?
#
#  ==== "Fake" attributes
#  place_name::             Allows User to enter location by name.
#  password_confirmation::  Used to confirm password during sign-up.
#
#  == Methods
#  current::              Report the User that is currently logged in.
#  current_id::           Report the User (id) that is currently logged in.
#  notes_template_parts:: Array of notes_template headings
#
#  ==== Names
#  text_name::          User name as: "loging" (for debugging)
#  legal_name::         User name as: "First Last" or "login"
#  unique_text_name::   User name as: "First Last (login)" or "login"
#
#  ==== Authentication
#  authenticate::       Verify login + password.
#  auth_code::          Code used to verify autologin cookie and POSTs in API.
#  change_password::    Change password (on an existing record).
#
#  ==== Interests
#  interest_in::        Return state of User's interest in a given object.
#  watching?::          Is User watching a given object?
#  ignoring?::          Is User ignoring a given object?
#
#  ==== Profile
#  percent_complete::   How much of profile has User finished?
#  sum_bonuses::        Add up all the bonuses User has earned.
#
#  ==== Object ownership
#  comments::           Comment's they've posted.
#  images::             Image's they've uploaded.
#  interests::          Interest's they've indicated.
#  locations::          Location's they were last to edit.
#  names::              Name's they were last to edit.
#  namings::            Naming's they've proposed.
#  name_trackers::      NameTracker's they've requested.
#  observations::       Observation's they've posted.
#  projects_created::   Project's they've created.
#  queued_emails::      QueuedEmail's they're scheduled to receive.
#  species_lists::      SpeciesList's they've created.
#  votes::              Vote's they've cast.
#
#  ==== Other relationships
#  to_emails::          QueuedEmail's they've caused to be sent.
#  user_groups::        UserGroup's they're members of.
#  in_group?::          Is User in a given UserGroup?
#  reviewed_images::    Image's they've reviewed.
#  reviewed_names::     Name's they've reviewed.
#  authored_names::     Name's they've authored.
#  edited_names::       Name's they've edited.
#  authored_locations:: Location's they've authored.
#  edited_locations::   Location's they've edited.
#  projects_admin::     Projects's they're an admin for.
#  projects_member::    Projects's they're a member of.
#  preferred_herbarium:: User's preferred herbarium
#                       (defaults to personal_herbarium).
#  personal_herbarium:: User's private herbarium:
#                       "Name (login): Personal Herbarium".
#  all_editable_species_lists:: Species Lists they own
#                       or that are attached to projects they're on.
#
#  ==== Other Stuff
#  erase_user::         Erase all references to a given User (by id).
#  remove_image::       Ensures that this user doesn't reference this image
#
#  == Callbacks
#  crypt_password::     Password attribute is encrypted
#                       before object is created.
#
class User < AbstractModel # rubocop:disable Metrics/ClassLength
  require "digest/sha1"

  # enum definitions for use by simple_enum gem
  # Do not change the integer associated with a value
  # first value is the default
  enum thumbnail_size:
       {
         thumbnail: 1,
         small: 2
       },
       _prefix: :thumb_size,
       _default: "thumbnail"

  enum image_size:
       {
         thumbnail: 1,
         small: 2,
         medium: 3,
         large: 4,
         huge: 5,
         full_size: 6
       },
       _prefix: true,
       _default: "medium"

  enum votes_anonymous:
       {
         no: 1,
         yes: 2,
         old: 3
       },
       _prefix: :votes_anon,
       _default: "no"

  enum location_format:
       {
         postal: 1,
         scientific: 2
       },
       _prefix: true,
       _default: "postal"

  enum hide_authors:
       {
         none: 1,
         above_species: 2
       },
       _prefix: true,
       _default: "none"

  enum keep_filenames:
       {
         toss: 1,
         keep_but_hide: 2,
         keep_and_show: 3
       },
       _suffix: :filenames,
       _default: "toss"

  has_many :api_keys, dependent: :destroy
  has_many :comments
  has_many :donations
  has_many :external_links
  has_many :images
  has_many :interests
  has_many :locations
  has_many :location_descriptions
  has_many :names
  has_many :name_descriptions
  has_many :name_trackers
  has_many :namings
  has_many :observations
  has_many :projects_created, class_name: "Project"
  has_many :project_members, dependent: :destroy
  has_many :projects, through: :project_members, source: :projects
  has_many :publications
  has_many :queued_emails
  has_many :sequences
  has_many :species_lists
  has_many :collection_numbers
  has_many :herbarium_records
  has_many :test_add_image_logs
  has_many :votes

  has_many :reviewed_images, class_name: "Image", foreign_key: "reviewer_id",
                             inverse_of: :reviewer
  has_many :reviewed_name_descriptions, class_name: "NameDescription",
                                        foreign_key: "reviewer_id",
                                        inverse_of: :reviewer
  has_many :to_emails, class_name: "QueuedEmail", foreign_key: "to_user_id",
                       inverse_of: :queued_email

  has_many :user_group_users, dependent: :destroy
  has_many :user_groups, through: :user_group_users

  has_many :herbarium_curators, dependent: :destroy
  has_many :curated_herbaria, through: :herbarium_curators, source: :herbarium

  has_many :name_description_authors, dependent: :destroy
  has_many :authored_names, through: :name_description_authors,
                            source: :name_description

  has_many :name_description_editors, dependent: :destroy
  has_many :edited_names, through: :name_description_editors,
                          source: :name_description

  has_many :location_description_authors, dependent: :destroy
  has_many :authored_locations, through: :location_description_authors,
                                source: :location_description

  has_many :location_description_editors, dependent: :destroy
  has_many :edited_locations, through: :location_description_editors,
                              source: :location_description

  belongs_to :image, inverse_of: :profile_users # mug shot
  belongs_to :license       # user's default license
  belongs_to :location      # primary location

  serialize :content_filter, type: Hash

  ##############################################################################
  #
  #  :section: Callbacks and Other Basic Stuff
  #
  ##############################################################################

  # Encrypt password before saving the first time.  (Subsequent modifications
  # go through +change_password+.)
  before_create :crypt_password

  before_update :update_image_copyright_holder
  before_update :expire_caches_of_associated_observations

  # Ensure that certain default values are symbols (rather than strings)
  # might only be an issue for test environment?
  # Probably better to instead use after_create and after_update,
  # as after_initialize will get called every time a User is instantiated.
  # I don't understand why this is needed at all.  Smells like something
  # else is wrong if we have to do this hack...
  # after_initialize :symbolize_values

  # This causes the data structures in these fields to be serialized
  # automatically with YAML and stored as plain old text strings.
  serialize :bonuses
  serialize :alert

  scope :by_contribution, lambda {
    order(contribution: :desc, name: :asc, login: :asc)
  }

  # These are used by forms.
  attr_accessor :place_name
  attr_accessor :email_confirmation

  # Used to let User enter password confirmation when signing up or changing
  # password.
  attr_accessor :password_confirmation

  # Find admin's record.
  def self.admin
    User.first
  end

  # Find admin's record.
  def self.admin_id
    User.first.id
  end

  # Report which User is currently logged in. Returns +nil+ if none.  This is
  # the same instance as is in the controllers' +@user+ instance variable.
  #
  #   user = User.current
  #
  def self.current
    @@user = nil unless defined?(@@user)
    @@user
  end

  # Report which User is currently logged in. Returns id, or +nil+ if none.
  #
  #   user_id = User.current_id
  #
  def self.current_id
    @@user = nil unless defined?(@@user)
    @@user&.id
  end

  # Tell User model which User is currently logged in (if any).  This is used
  # by the +autologin+ filter and API authentication.
  def self.current=(val)
    @@location_format = val ? val.location_format : "postal"
    @@user = val
  end

  # Report current user's preferred location_format
  #
  #   location_format = User.current_location_format
  #
  def self.current_location_format
    @@location_format = "postal" unless defined?(@@location_format)
    @@location_format
  end

  # Set the location format to use throughout the site.
  def self.current_location_format=(val)
    @@location_format = val
  end

  # Clear cached data structures when reload.
  def reload
    @projects_admin = nil
    @projects_member = nil
    @all_editable_species_lists = nil
    @interests = nil
    super
  end

  # User is the only one allowed to edit their own account info.
  def can_edit?(user = User.current)
    user == self
  end

  # Improve debug and error message readability.
  def inspect
    "#<User #{id}: #{unique_text_name.inspect}>"
  end

  # For now just special exception to keep Adolf from wasting my life.
  def hide_specimen_stuff?
    id == 2873
  end

  ##############################################################################
  #
  #  :section: Names
  #
  ##############################################################################

  # Returns +login+ for debugging.
  def text_name
    login.to_s
  end

  # Return User's full name (if present) together with login.  This is
  # guaranteed to be unique.
  #
  #   name present:  "Fred Flintstone (fred99)"
  #   name missing:  "fred99"
  #
  def unique_text_name
    if name.blank?
      login
    else
      name + " (#{login})"
    end
  end

  def format_name
    unique_text_name
  end

  # Return User's full name if present, else return login.
  #
  #   name present:  "Fred Flintstone"
  #   name missing:  "fred99"
  #
  def legal_name
    if name.to_s == ""
      login
    else
      name
    end
  end

  def legal_name_changed?
    !legal_name_change.nil?
  end

  def legal_name_change
    old_name = name_change ? name_change[0] : name
    old_login = login_change ? login_change[0] : login
    old_legal_name = old_name.presence || old_login
    new_legal_name = legal_name
    return nil if old_legal_name == new_legal_name

    [old_legal_name, new_legal_name]
  end

  # TODO: Move this to an ActiveJob, once we get jobs going - AN 20240220
  # This can be fairly expensive if the user has a lot of images
  def update_image_copyright_holder
    return unless legal_name_change

    Image.update_copyright_holder(*legal_name_change, self)
  end

  # EXPIRE CACHES OF OBS WITH CHANGED USER LOGINS
  # "touch" the updated_at column of all observations with the changed login
  def expire_caches_of_associated_observations
    return unless name_changed? || login_changed?

    Observation.where(user_id: id).touch_all
  end

  ##############################################################################
  #
  #  :section: Authentication
  #
  ##############################################################################

  # Look up User record by login and hashed password.  Accepts any of +login+,
  # +name+ or +email+ in place of +login+.
  #
  #   user = User.authenticate(login: 'fred', password: 'password')
  #   user = User.authenticate(login: 'Fred Flintstone', password: 'password')
  #   user = User.authenticate(login: 'fred99@aol.com', password: 'password')
  #
  def self.authenticate(login: nil, password: nil)
    User.find_by(
      User[:login].eq(login).
      or(User[:name].eq(login)).
      or(User[:email].eq(login)).
      and(User[:password].eq(sha1(password)))
    )
  end

  # Change password: pass in unecrypted password, sets 'password' attribute
  # with a hashed copy (that is what is stored in the database).
  #
  #   user.change_password('new_password')
  #
  def change_password(pass)
    update_attribute("password", self.class.sha1(pass)) if pass.present?
  end

  # Mark a User account as "verified".
  def verify
    now = Time.zone.now
    self.verified = now
    self.last_login = now
    self.last_activity = now
    save
  end

  ##############################################################################
  #
  #  :section: Groups
  #
  ##############################################################################

  # Is the User in a given UserGroup?  (Specify group by name, not id.)
  #
  #   user.in_group?('reviewers')
  #
  def in_group?(group)
    if group.is_a?(UserGroup)
      user_groups.include?(group)
    else
      user_groups.any? { |g| g.name == group.to_s }
    end
  end

  # Return an Array of Project's that this User is an admin for.
  def projects_admin
    Project.joins(:admin_group_users).where(user_id: id)
  end

  # Return an Array of Project's that this User is a member of.
  def projects_member(order: :created_at, include: nil)
    @projects_member ||= Project.where(user_group: user_groups.ids).
                         includes(include).order(order).to_a
  end

  # Return an Array of ExternalSite's that this user has permission to add
  # links for.
  def external_sites
    @external_sites ||= ExternalSite.where(project: projects_member)
  end

  def preferred_herbarium_name
    preferred_herbarium.name
  rescue StandardError
    personal_herbarium_name
  end

  # Return the name of this user's "favorite" herbarium
  # (meaning the one they have used the most).
  # TODO: Make this a user preference.
  def preferred_herbarium
    @preferred_herbarium ||=
      begin
        herbarium_id = HerbariumRecord.where(user_id: id).
                       order(created_at: :desc).limit(1).
                       pick(:herbarium_id)
        if herbarium_id.blank?
          personal_herbarium
        else
          Herbarium.find(herbarium_id)
        end
      end
  end

  # Offers a default fallback for personal herbarium name
  # Can't call personal_herbarium&.name here because instance var may be stale
  def personal_herbarium_name
    Herbarium.find_by(personal_user_id: id)&.name ||
      :user_personal_herbarium.l(name: unique_text_name)
  end

  def personal_herbarium
    @personal_herbarium ||= Herbarium.find_by(personal_user_id: id)
  end

  def create_personal_herbarium
    # rubocop:disable Naming/MemoizedInstanceVariableName
    @personal_herbarium ||= Herbarium.create(
      name: personal_herbarium_name,
      email: email,
      personal_user: self,
      curators: [self]
    )
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end

  # Return an ActiveRecord::Association of SpeciesList's that User created or
  # that are attached to a Project that the User is a member of.
  def all_editable_species_lists
    @all_editable_species_lists ||=
      if projects_member.any?
        SpeciesList.
          where(SpeciesList[:user_id].eq(id).
          or(SpeciesList[:id].in(species_lists_in_users_projects))).distinct
      else
        species_lists
      end
  end

  def species_lists_in_users_projects
    project_ids = projects_member.map(&:id)
    ProjectSpeciesList.where(project_id: project_ids).distinct.
      pluck(:species_list_id)
  end

  ##############################################################################
  #
  #  :section: Interests and Tracking
  #
  ##############################################################################

  # Has this user expressed positive or negative interest in a given object?
  # Returns +:watching+ or +:ignoring+ if so, else +nil+.  Caches result.
  #
  #   case user.interest_in(observation)
  #   when :watching; ...
  #   when :ignoring; ...
  #   end
  #
  def interest_in(object)
    @interests ||= {}
    @interests["#{object.class.name} #{object.id}"] ||= \
      begin
        i = Interest.where(
          user_id: id, target_type: object.class.name, target_id: object.id
        ).pick(:state)
        case i
        when true
          :watching
        when false
          :ignoring
        end
      end
  end

  # Has this user expressed positive interest in a given object?
  #
  #   user.watching?(observation)
  #
  def watching?(object)
    interest_in(object) == :watching
  end

  # Has this user expressed negative interest in a given object?
  #
  #   user.ignoring?(name)
  #
  def ignoring?(object)
    interest_in(object) == :ignoring
  end

  def mailing_address_for_tracking_template
    result = mailing_address.strip if mailing_address
    result = "**insert mailing address for specimens**" if result.blank?
    result
  end

  ##############################################################################
  #
  #  :section: Profile
  #
  ##############################################################################

  # Calculate the User's progress in completing their profile.  It is currently
  # based on three equal factors:
  # * notes = 33%
  # * location = 33%
  # * image = 33%
  #
  def percent_complete
    max = 3
    result = 0
    result += 1 if notes && notes != ""
    result += 1 if location_id
    result += 1 if image_id
    result * 100 / max
  end

  # Sum up all the bonuses the User has earned.
  #
  #   contribution += user.sum_bonuses
  #
  def sum_bonuses
    return nil unless bonuses

    bonuses.inject(0) { |acc, elem| acc + elem[0] }
  end

  def successful_contributor?
    observations.any?
  end

  ##############################################################################
  #
  #  :section: Notes Template
  #
  ##############################################################################

  # Array of user defined headings for Notes when creating Observations
  # notes_template: "odor , Nearest tree"
  # notes_template_parts # => ["odor", "Nearest tree"]
  # notes_template: ""
  # notes_template_parts # => []
  def notes_template_parts
    return [] if notes_template.blank?

    User.parse_notes_template(notes_template)
  end

  def notes_template=(str)
    str = User.parse_notes_template(str).join(", ")
    self[:notes_template] = str
  end

  def self.parse_notes_template(str)
    str.to_s.gsub(/[\x00-\x07\x09\x0B\x0C\x0E-\x1F\x7F]/, "").
      split(",").map(&:squish).compact_blank
  end

  def self.cull_unverified_users(dry_run: false)
    ids = User.where(verified: nil, created_at: ..1.month.ago).pluck(:id)
    return [] if ids.blank?

    unless dry_run
      ids.each do |id|
        UserGroup.one_user(id)&.destroy
      end
      UserGroupUser.where(user_id: ids).delete_all
      User.where(id: ids).delete_all
    end

    ["Deleted #{ids.count} unverified user(s)."]
  end

  # Erase all references to a given user (by id).  Missing:
  # 1) *Text* references, e.g., RssLog entries refering to their login.
  # 2) Image votes.
  # 3) Personal descriptions and drafts.
  def self.erase_user(id)
    blank_out_public_references(id)
    delete_one_user_group_references(id)
    delete_observations_attachments(id)
    delete_own_records(id)
  end

  PUBLIC_REFERENCES = [
    [:herbaria,                       :personal_user_id],
    [:location_descriptions,          :user_id],
    [:location_description_versions, :user_id],
    [:locations,                      :user_id],
    [:location_versions,             :user_id],
    [:name_descriptions,              :user_id],
    [:name_descriptions,              :reviewer_id],
    [:name_description_versions,     :user_id],
    [:names,                          :user_id],
    [:name_versions,                 :user_id],
    # Leave projects, because they're intertwined with descriptions too much.
    [:projects,                       :user_id],
    # Leave votes and namings, because I don't want to recalc consensuses.
    [:namings,                        :user_id],
    [:projects,                       :user_id],
    [:translation_strings,            :user_id],
    [:translation_string_versions,   :user_id],
    [:votes,                          :user_id]
  ].freeze

  # Blank out any references in public records.
  private_class_method def self.blank_out_public_references(id)
    PUBLIC_REFERENCES.each do |table, col|
      model = get_model_for_table(table)
      model.where("#{col}": id).update_all("#{col}": 0)
    end
  end

  ONE_USER_GROUP_REFERENCES = [
    [:location_description_admins,  :user_group_id],
    [:location_description_readers, :user_group_id],
    [:location_description_writers, :user_group_id],
    [:name_description_admins,      :user_group_id],
    [:name_description_readers,     :user_group_id],
    [:name_description_writers,     :user_group_id],
    [:user_groups,                  :id]
  ].freeze

  # Delete references to their one-user group.
  private_class_method def self.delete_one_user_group_references(id)
    group = UserGroup.one_user(id)
    return unless group

    group_id = group.id

    ONE_USER_GROUP_REFERENCES.each do |table, col|
      model = get_model_for_table(table)
      model.where("#{col}": group_id).delete_all
    end
  end

  OBSERVATIONS_ATTACHMENTS = [
    [:observation_collection_numbers, :observation_id],
    [:comments,                       :target_id, :target_type],
    [:observation_herbarium_records,  :observation_id],
    [:observation_images,             :observation_id],
    [:interests,                      :target_id, :target_type],
    [:namings,                        :observation_id],
    [:rss_logs,                       :observation_id],
    [:sequences,                      :observation_id],
    [:votes,                          :observation_id]
  ].freeze

  # Delete their observations' attachments.
  private_class_method def self.delete_observations_attachments(id)
    obs_ids = Observation.where(user_id: id).pluck(:id)
    return unless obs_ids.any?

    OBSERVATIONS_ATTACHMENTS.each do |table, id_col, type_col|
      delete_obs_attachments_from_one_table(
        obs_ids, table, id_col, type_col
      )
    end
  end

  private_class_method def self.delete_obs_attachments_from_one_table(
    obs_ids, table, id_col, type_col
  )
    model = get_model_for_table(table)
    model = model.where("#{type_col}": "Observation") if type_col
    model.where("#{id_col}": obs_ids).delete_all
  end

  OWN_RECORDS = [
    [:api_keys,                       :user_id],
    [:articles,                       :user_id],
    [:collection_numbers,             :user_id],
    [:comments,                       :user_id],
    [:copyright_changes,              :user_id],
    [:donations,                      :user_id],
    [:external_links,                 :user_id],
    [:glossary_terms,                 :user_id],
    [:glossary_term_versions,        :user_id],
    [:herbaria,                       :personal_user_id],
    [:herbarium_curators,             :user_id],
    [:herbarium_records,              :user_id],
    [:images,                         :user_id],
    [:image_votes,                    :user_id],
    [:interests,                      :user_id],
    [:location_description_authors,   :user_id],
    [:location_description_editors,   :user_id],
    [:name_description_authors,       :user_id],
    [:name_description_editors,       :user_id],
    [:name_trackers,                  :user_id],
    [:observations,                   :user_id],
    [:publications,                   :user_id],
    [:queued_emails,                  :user_id],
    [:queued_emails,                  :to_user_id],
    [:sequences,                      :user_id],
    [:species_lists,                  :user_id],
    [:user_group_users,               :user_id],
    [:users,                          :id]
  ].freeze

  # Delete records they created, culminating in the user record itself.
  private_class_method def self.delete_own_records(id)
    OWN_RECORDS.each do |table, col|
      model = get_model_for_table(table)
      model.where("#{col}": id).delete_all
    end
  end

  # Derive the model from the table name. Versions are namespaced
  private_class_method def self.get_model_for_table(table)
    table_name = table.to_s
    if table_name.end_with?("versions")
      parent_table_name = table_name.delete_suffix("_versions")
      parent_table_name.singularize.camelize.constantize::Version
    else
      table_name.singularize.camelize.constantize
    end
  end

  def remove_image(image)
    return unless self.image == image

    self.image = nil
    save
  end

  ##############################################################################

  # This is intended to comply with Apple's requirement that we allow users
  # to delete their account.  We do not want to let users remove everything,
  # though, like for example, their comments within comment threads on other
  # users' observations, as doing so may render those threads unintelligible.
  # Legally speaking, as everything on MO is posted under Creative Commons
  # licenses, we are perfectly within our rights to retain users' content.
  # But we wish to comply with Apple where it will not otherwise detract from
  # other users' experience.
  def disable_account_and_delete_private_objects
    disable_account
    delete_api_keys
    delete_interests
    delete_name_trackers
    delete_queued_emails
    delete_observations
    delete_private_name_descriptions
    delete_private_location_descriptions
    delete_private_projects
    delete_private_species_lists
    delete_unattached_collection_numbers
    delete_unattached_herbarium_records
    delete_unattached_images
    User.erase_user(id) if no_references_left?
  end

  # Disable and remove all public information from account but leave it there
  # in case there are still comments, etc. on the site by this user.
  def disable_account
    self.email = ""
    self.blocked = true
    self.location_id = nil
    self.image_id = nil
    self.notes = nil
    self.mailing_address = nil
    update_attribute(:password, "")
    save
  end

  def delete_api_keys
    api_keys.delete_all
  end

  def delete_interests
    interests.delete_all
  end

  def delete_name_trackers
    NameTracker.where(user: self).delete_all
  end

  def delete_queued_emails
    QueuedEmail.where(user_id: id).delete_all
    QueuedEmail.where(to_user_id: id).delete_all
  end

  def delete_observations
    [Naming, Vote, RssLog].each do |model|
      model.joins(:observation).where(observation: { user_id: id }).delete_all
    end
    # (all the rest of the observations' dependents should autodestruct)
    observations.delete_all
  end

  # Delete user's descriptions that don't have any other authors or editors.
  # (Oops, editors never got "hooked up" so we have to use versions instead.)
  def delete_private_name_descriptions
    ids = private_name_descriptions.map(&:id)
    NameDescription.where(id: ids).delete_all
    NameDescription::Version.where(name_description_id: ids).delete_all
  end

  def private_name_descriptions
    name_descriptions -
      name_descriptions.joins(:name_description_authors).
      where.not(name_description_authors: { user_id: id }) -
      name_descriptions.joins(:name_description_editors).
      where.not(name_description_editors: { user_id: id }) -
      name_descriptions.joins(:versions).
      where.not(versions: { user_id: id })
  end

  # Delete user's descriptions that don't have any other authors or editors.
  # (Oops, editors never got "hooked up" so we have to use versions instead.)
  def delete_private_location_descriptions
    ids = private_location_descriptions.map(&:id)
    LocationDescription.where(id: ids).delete_all
    LocationDescription::Version.where(location_description_id: ids).delete_all
  end

  def private_location_descriptions
    location_descriptions -
      location_descriptions.joins(:location_description_authors).
      where.not(location_description_authors: { user_id: id }) -
      location_descriptions.joins(:location_description_editors).
      where.not(location_description_editors: { user_id: id }) -
      location_descriptions.joins(:versions).
      where.not(versions: { user_id: id })
  end

  # Delete all the user's projects that don't have any other users on them.
  def delete_private_projects
    ids = (projects_created -
            projects_created.joins(:admin_group_users).
            where.not(admin_group_users: { id: id }) -
            projects_created.joins(:member_group_users).
            where.not(member_group_users: { id: id })).
          map(&:id)
    Project.where(id: ids).delete_all
  end

  # Delete all species lists the user created unless they belong to a project.
  # (Private projects should already have been deleted by this point, so this
  # in effect, really should read "unless they belong to a public project".)
  # I think it's okay to delete observations even if they are attached to a
  # project.  But species_lists are potentially a much more collaborative
  # effort, so I don't think it's okay to delete lists that are attached to
  # public projects just because the user happened to originally create them.
  # -JPH 20220916
  def delete_private_species_lists
    ids = (species_lists - species_lists.joins(:project_species_lists)).
          map(&:id)
    SpeciesList.where(id: ids).delete_all
  end

  def delete_unattached_collection_numbers
    ids = (collection_numbers -
            collection_numbers.joins(:observation_collection_numbers)).
          map(&:id)
    CollectionNumber.where(id: ids).delete_all
  end

  def delete_unattached_herbarium_records
    ids = (herbarium_records -
            herbarium_records.joins(:observation_herbarium_records)).
          map(&:id)
    HerbariumRecord.where(id: ids).delete_all
  end

  def delete_unattached_images
    ids = (images -
            images.joins(:glossary_term_images) -
            images.joins(:observation_images) -
            images.joins(:project_images) -
            images.joins(:profile_users)).
          map(&:id)
    Image.where(id: ids).delete_all
  end

  REFERENCE_MODELS = [
    # APIKey,                        (just deleted all of these)
    Article,
    CollectionNumber,
    Comment,
    # CopyrightChange,               (okay if these are all that's left)
    # Donation,                      (okay if these are all that's left)
    ExternalLink,
    GlossaryTerm,
    GlossaryTerm::Version,
    # Herbarium, (personal_user_id)  (okay if these are all that's left)
    # HerbariumCurator,              (okay if these are all that's left)
    HerbariumRecord,
    ImageVote,
    Image,
    # Interest,                      (just deleted all of these)
    Location,
    Location::Version,
    LocationDescription,
    LocationDescription::Version,
    LocationDescriptionAuthor,
    LocationDescriptionEditor,
    Name,
    Name::Version,
    NameDescription,
    NameDescription::Version,
    NameDescriptionAuthor,
    NameDescriptionEditor,
    Naming,
    # NameTracker,                  (just deleted all of these)
    # ObservationView,               (okay if these are all that's left)
    # Observation,                   (just deleted all of these)
    Project,
    Publication,
    # QueuedEmail,                   (just deleted all of these)
    # QueuedEmail, (to_user_id)      (just deleted all of these)
    Sequence,
    SpeciesList,
    TranslationString,
    TranslationString::Version,
    # UserGroupUser,                 (okay if these are all that's left)
    Vote
  ].freeze

  def no_references_left?
    REFERENCE_MODELS.all? do |model|
      model.where(user_id: id).none?
    end
  end

  ##############################################################################

  # Encrypt a password.
  def self.sha1(pass)
    Digest::SHA1.hexdigest("something__#{pass}__")
  end

  # Encrypted code used in autologin cookie and API authentication.
  def self.old_auth_code(password)
    Digest::SHA1.hexdigest("SdFgJwLeR#{password}WeRtWeRkTj")
  end

  # This is a +before_create+ callback that encrypts the password before saving
  # the new user record.  (Not needed for updates because we use
  # change_password for that instead.)
  def crypt_password
    self["password"] = self.class.sha1(password) if password.present?
    self["auth_code"] = String.random(40)
  end

  ##############################################################################

  private

  validate :user_requirements
  validate :check_password, on: :create
  # `if` accounts for existing invalid entries; otherwise users cannot update
  validate :user_email_requirements, if: proc { |c|
    c.new_record? || c.email_changed?
  }
  validate :notes_template_forbid_other
  validate :notes_template_forbid_duplicates
  validate :check_content_filter_region, if: proc { |c|
    c.new_record? || c.content_filter_changed?
  }

  def user_requirements
    user_login_requirements if new_record? || login_changed?
    user_password_requirements if new_record? || password_changed?
    user_other_requirements
  end

  def user_login_requirements
    if login.to_s.blank?
      errors.add(:login, :validate_user_login_missing.t)
    elsif login.length < 3 || login.size > 40
      errors.add(:login, :validate_user_login_too_long.t)
    elsif login_already_taken?
      errors.add(:login, :validate_user_login_taken.t)
    end
  end

  # This is a pricey lookup, avoid if not changing login
  def login_already_taken?
    other = User.find_by(login: login)
    other && other.id != id
  end

  def user_password_requirements
    errors.add(:password, :validate_user_password_too_long.t) \
      if password.to_s.present? && (password.length < 5 || password.size > 40)
  end

  def user_email_requirements
    if email.to_s.blank? || !ApplicationMailer.valid_email_address?(email.to_s)
      errors.add(:email, :validate_user_email_missing.t)
    elsif email.size > 80
      errors.add(:email, :validate_user_email_too_long.t)
    end
  end

  def user_other_requirements
    errors.add(:theme, :validate_user_theme_too_long.t) if theme.to_s.size > 40
    errors.add(:name, :validate_user_name_too_long.t) if name.to_s.size > 80
  end

  def check_password
    return if password.blank?

    if password_confirmation.to_s.blank?
      errors.add(:password, :validate_user_password_confirmation_missing.t)
    elsif password != password_confirmation
      errors.add(:password, :validate_user_password_no_match.t)
    end
  end

  def notes_template_forbid_other
    notes_template_bad_parts.each do |part|
      errors.add(:notes_template, :prefs_notes_template_no_other.t(part: part))
    end
  end

  def notes_template_forbid_duplicates
    return if notes_template.blank?

    squished = notes_template.split(",").map(&:squish)
    dups = squished.uniq.select { |part| squished.count(part) > 1 }
    dups.each do |dup|
      errors.add(:notes_template, :prefs_notes_template_no_dups.t(part: dup))
    end
  end

  def notes_template_bad_parts
    return [] if notes_template.blank?

    notes_template.split(",").each_with_object([]) do |part, a|
      next unless notes_template_reserved_words.include?(part.squish.downcase)

      a << part.strip
    end
  end

  # list of words which cannot be headings in user template
  # 'Other' is already used by MO for notes without a heading.
  # The rest won't break the application but would be confusing.
  #
  # 'other' plus other words is valid, e.g.,
  # notes_template = "Cap color, Cap size, Cap other"
  def notes_template_reserved_words
    [Observation.other_notes_part.downcase].concat(notes_other_translations)
  end

  def notes_other_translations
    %w[andere altro altra autre autres otra otras otro otros outros]
  end

  # Check if region is provided and is in fact a valid region with locations,
  # i.e. the end of a location name string
  def check_content_filter_region
    return if content_filter[:region].blank?
    return if Location.in_region(content_filter[:region]).any?

    # If we're here, there are no MO locations in that region.
    errors.add(:region, :advanced_search_filter_region.t)
  end
end
