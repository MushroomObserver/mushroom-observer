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
#     below).  This causes the User to be redirected to <tt>/account/login</tt>.
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
#     form.  Inside the email is a link to /account/verify.  This provides the
#     User +id+ and +auth_code+.
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
#  2. +check_user_alert+: Check if User has an alert to show, redirecting if so.
#
#  3. +set_locale+: Check if User has chosen a locale.
#
#  4. +set_timezone+: Set timezone from cookie set by client's browser.
#
#  5. +login_required+: (optional) Redirects to <tt>/account/login</tt> if not
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
#  == Alerts
#
#  Admins can create an alert for a User.  These are messages that they will
#  see the very next time they try to load a page.  Only one is allowed at a
#  time for the User right now.  All the information about the alert is stored
#  in a simple hash which is stored, serialized, as a +text+ column in the
#  database.  When the User sees the message, they have three options:
#
#  1. Acknowledge the alert by clicking on "okay", and the alert is deleted.
#  2. Tell it to display the message again in a day (see +alert_next_showing+).
#  3. Exit or navigate away without acknowledging it, causing the alert to be
#     shown over and over until they get tired and say "okay".
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
#  notifications::      Notification's they've requested.
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
#  ==== Alerts
#  all_alert_types::    List of accepted alert types.
#  alert_user::         Which admin created the alert.
#  alert_created_at::   When alert was created.
#  alert_next_showing:: When is the alert going to be shown next?
#  alert_type::         What type of alert, e.g., :bounced_email.
#  alert_notes::        Additional notes to add to message.
#  alert_message::      Actual message, translated into local language.
#
#  ==== Other Stuff
#  primer::             Primer for auto-complete.
#  erase_user::         Erase all references to a given User (by id).
#  remove_image::       Ensures that this user doesn't reference this image
#
#  == Callbacks
#  crypt_password::     Password attribute is encrypted
#                       before object is created.
#
class User < AbstractModel
  require "digest/sha1"

  # enum definitions for use by simple_enum gem
  # Do not change the integer associated with a value
  # first value is the default
  as_enum(:thumbnail_size,
          {
            thumbnail: 1,
            small: 2
          },
          source: :thumbnail_size,
          accessor: :whiny)
  as_enum(:image_size,
          {
            thumbnail: 1,
            small: 2,
            medium: 3,
            large: 4,
            huge: 5,
            full_size: 6
          },
          source: :image_size,
          accessor: :whiny)
  as_enum(:votes_anonymous,
          {
            no: 1,
            yes: 2,
            old: 3
          },
          source: :votes_anonymous,
          accessor: :whiny)
  as_enum(:location_format,
          {
            postal: 1,
            scientific: 2
          },
          source: :location_format,
          accessor: :whiny)
  as_enum(:hide_authors,
          {
            none: 1,
            above_species: 2
          },
          source: :hide_authors,
          accessor: :whiny)
  as_enum(:keep_filenames,
          {
            toss: 1,
            keep_but_hide: 2,
            keep_and_show: 3
          },
          source: :keep_filenames,
          accessor: :whiny)

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
  has_many :namings
  has_many :notifications
  has_many :observations
  has_many :projects_created, class_name: "Project"
  has_many :publications
  has_many :queued_emails
  has_many :sequences
  has_many :species_lists
  has_many :herbarium_records
  has_many :test_add_image_logs
  has_many :votes

  has_many :reviewed_images, class_name: "Image", foreign_key: "reviewer_id"
  has_many :reviewed_name_descriptions, class_name: "NameDescription",
                                        foreign_key: "reviewer_id"
  has_many :to_emails, class_name: "QueuedEmail", foreign_key: "to_user_id"

  has_and_belongs_to_many :user_groups,
                          class_name: "UserGroup",
                          join_table: "user_groups_users"
  has_and_belongs_to_many :authored_names,
                          class_name: "NameDescription",
                          join_table: "name_descriptions_authors"
  has_and_belongs_to_many :edited_names,
                          class_name: "NameDescription",
                          join_table: "name_descriptions_editors"
  has_and_belongs_to_many :authored_locations,
                          class_name: "LocationDescription",
                          join_table: "location_descriptions_authors"
  has_and_belongs_to_many :edited_locations,
                          class_name: "LocationDescription",
                          join_table: "location_descriptions_editors"
  has_and_belongs_to_many :curated_herbaria,
                          class_name: "Herbarium",
                          join_table: "herbaria_curators"

  belongs_to :image         # mug shot
  belongs_to :license       # user's default license
  belongs_to :location      # primary location

  serialize :content_filter, Hash

  ##############################################################################
  #
  #  :section: Callbacks and Other Basic Stuff
  #
  ##############################################################################

  # Encrypt password before saving the first time.  (Subsequent modifications
  # go through +change_password+.)
  before_create :crypt_password

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

  # These are used by forms.
  attr_accessor :place_name
  attr_accessor :email_confirmation

  # Used to let User enter password confirmation when signing up or changing
  # password.
  attr_accessor :password_confirmation

  # Override the default show_controller
  def self.show_controller
    "observer"
  end

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
    @@user && @@user.id
  end

  # Tell User model which User is currently logged in (if any).  This is used
  # by the +autologin+ filter and API authentication.
  def self.current=(x)
    @@location_format = x ? x.location_format : :postal
    @@user = x
  end

  # Report current user's preferred location_format
  #
  #   location_format = User.current_location_format
  #
  def self.current_location_format
    @@location_format = :postal unless defined?(@@location_format)
    @@location_format
  end

  # Set the location format to use throughout the site.
  def self.current_location_format=(x)
    @@location_format = x
  end

  # Did current user opt to view owner_id's?
  def self.view_owner_id_on?
    try(:current).try(:view_owner_id)
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
    if name.to_s != ""
      name
    else
      login
    end
  end

  def legal_name_changed?
    !legal_name_change.nil?
  end

  def legal_name_change
    old_name = name_change ? name_change[0] : name
    old_login = login_change ? login_change[0] : login
    old_legal_name = old_name.blank? ? old_login : old_name
    new_legal_name = legal_name
    return nil if old_legal_name == new_legal_name
    [old_legal_name, new_legal_name]
  end

  ##############################################################################
  #
  #  :section: Authentication
  #
  ##############################################################################

  # Look up User record by login and hashed password.  Accepts any of +login+,
  # +name+ or +email+ in place of +login+.
  #
  #   user = User.authenticate('fred', 'password')
  #   user = User.authenticate('Fred Flintstone', 'password')
  #   user = User.authenticate('fred99@aol.com', 'password')
  #
  def self.authenticate(login, pass)
    where("(login = ? OR name = ? OR email = ?) AND password = ? AND
           password != '' ",
          login, login, login, sha1(pass)).first
  end

  # Change password: pass in unecrypted password, sets 'password' attribute
  # with a hashed copy (that is what is stored in the database).
  #
  #   user.change_password('new_password')
  #
  def change_password(pass)
    update_attribute "password", self.class.sha1(pass) unless pass.blank?
  end

  # Mark a User account as "verified".
  def verify
    now = Time.now
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
    @projects_admin ||= Project.find_by_sql %(
      SELECT projects.* FROM projects, user_groups_users
      WHERE projects.admin_group_id = user_groups_users.user_group_id
        AND user_groups_users.user_id = #{id}
    )
  end

  # Return an Array of Project's that this User is a member of.
  def projects_member
    @projects_member ||= Project.find_by_sql %(
      SELECT projects.* FROM projects, user_groups_users
      WHERE projects.user_group_id = user_groups_users.user_group_id
        AND user_groups_users.user_id = #{id}
    )
  end

  # Return an Array of ExternalSite's that this user has permission to add
  # links for.
  def external_sites
    @external_sites ||= ExternalSite.where(project: projects_member)
  end

  def preferred_herbarium_name
    preferred_herbarium.name
  rescue
    personal_herbarium_name
  end

  # Return the name of this user's "favorite" herbarium
  # (meaning the one they have used the most).
  # TODO: Make this a user preference.
  def preferred_herbarium
    @preferred_herbarium ||= begin
      herbarium_id = Herbarium.connection.select_value(%(
        SELECT herbarium_id FROM herbarium_records WHERE user_id=#{id}
        ORDER BY created_at DESC LIMIT 1
      ))
      herbarium_id.blank? ? personal_herbarium : Herbarium.find(herbarium_id)
    end
  end

  def personal_herbarium_name
    Herbarium.connection.select_value(%(
      SELECT name FROM herbaria WHERE personal_user_id = #{id} LIMIT 1
    )) || :user_personal_herbarium.l(name: unique_text_name)
  end

  def personal_herbarium
    @personal_herbarium ||= Herbarium.where(personal_user_id: id).first
  end

  def create_personal_herbarium
    @personal_herbarium ||= Herbarium.create(
      name:          personal_herbarium_name,
      email:         email,
      personal_user: self,
      curators:      [self]
    )
  end

  # Return an Array of SpeciesList's that User owns or that are attached to a
  # Project that the User is a member of.
  def all_editable_species_lists
    @all_editable_species_lists ||= begin
      results = species_lists
      if projects_member.any?
        project_ids = projects_member.map(&:id).join(",")
        results += SpeciesList.find_by_sql %(
          SELECT species_lists.* FROM species_lists, projects_species_lists
          WHERE species_lists.user_id != #{id}
            AND projects_species_lists.project_id IN (#{project_ids})
            AND projects_species_lists.species_list_id = species_lists.id
        )
      end
      results
    end
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
    @interests["#{object.class.name} #{object.id}"] ||= begin
      state = Interest.connection.select_value(%(
        SELECT state FROM interests
        WHERE user_id = #{id}
          AND target_type = '#{object.class.name}'
          AND target_id = #{object.id}
        LIMIT 1
      )).to_s
      if state == "1"
        :watching
      elsif state == "0"
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

  def is_successful_contributor?
    observations.any?
  end

  ##############################################################################
  #
  #  :section: Alerts
  #
  ##############################################################################

  # List of all allowed alert types.
  #
  #   raise unless User.all_alert_types.include? :bogus_alert
  #
  def self.all_alert_types
    [:bounced_email, :other]
  end

  # Get alert structure, initializing it with an empty hash if necessary.
  def get_alert # :nodoc:
    self.alert ||= {}
  end
  protected :get_alert

  # When the alert was created.
  def alert_created_at
    get_alert[:created_at]
  end

  def alert_created_at=(x)
    get_alert[:created_at] = x
  end

  # ID of the admin User that created the alert.
  def alert_user_id
    get_alert[:user_id]
  end

  def alert_user_id=(x)
    get_alert[:user_id] = x
  end

  # Instance of admin User that created the alert.
  def alert_user
    User.find(alert_user_id)
  end

  def alert_user=(x)
    get_alert[:user_id] = x ? x.id : nil
  end

  # Next time the alert will be shown.
  def alert_next_showing
    get_alert[:next_showing]
  end

  def alert_next_showing=(x)
    get_alert[:next_showing] = x
  end

  # Type of alert (e.g., :bounced_email).
  def alert_type
    get_alert[:type]
  end

  def alert_type=(x)
    get_alert[:type] = x
  end

  # Additional notes admin added when creating alert.
  def alert_notes
    get_alert[:notes]
  end

  def alert_notes=(x)
    get_alert[:notes] = x
  end

  # Get the localization string for the alert message for this type of alert.
  # This is the actual message that will be displayed for the user in question.
  #
  #   <%= user.alert_message.tp %>
  #
  def alert_message
    "user_alert_message_#{alert_type}".to_sym
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
    write_attribute(:notes_template, str)
  end

  def self.parse_notes_template(str)
    str.to_s.gsub(/[\x00-\x07\x09\x0B\x0C\x0E-\x1F\x7F]/, "").
        split(",").map(&:squish).reject(&:blank?)
  end

  ##############################################################################
  #
  #  :section: Other
  #
  ##############################################################################

  # Get list of users to prime auto-completer.  Returns a simple Array of up to
  # 1000 (by contribution or created within the last month) login String's
  # (with full name in parens).
  def self.primer
    result = []
    if !File.exist?(MO.user_primer_cache_file) ||
       File.mtime(MO.user_primer_cache_file) < Time.now - 1.day

      # Get list of users sorted first by when they last logged in (if recent),
      # then by cotribution.
      result = connection.select_values(%(
        SELECT CONCAT(users.login,
                      IF(users.name = "", "", CONCAT(" <", users.name, ">")))
        FROM users
        ORDER BY IF(last_login > CURRENT_TIMESTAMP - INTERVAL 1 MONTH,
                    last_login, NULL) DESC,
                 contribution DESC
        LIMIT 1000
      )).uniq.sort

      File.open(MO.user_primer_cache_file, "w:utf-8").
        write(result.join("\n") + "\n")
    else
      result = File.open(MO.user_primer_cache_file, "r:UTF-8").
               readlines.map(&:chomp)
    end
    result
  end

  # Erase all references to a given user (by id).  Missing:
  # 1) *Text* references, e.g., RssLog entries refering to their login.
  # 2) Image votes.
  # 3) Personal descriptions and drafts.
  def self.erase_user(id)
    # Blank out any references in public records.
    [
      [:location_descriptions,          :user_id],
      [:location_descriptions_versions, :user_id],
      [:locations,                      :user_id],
      [:locations_versions,             :user_id],
      [:name_descriptions,              :user_id],
      [:name_descriptions,              :reviewer_id],
      [:name_descriptions_versions,     :user_id],
      [:names,                          :user_id],
      [:names_versions,                 :user_id],
      # Leave projects, because they're intertwined with descriptions too much.
      [:projects,                       :user_id],
      # Leave votes and namings, because I don't want to recalc consensuses.
      [:namings,                        :user_id],
      [:projects,                       :user_id],
      [:translation_strings,            :user_id],
      [:translation_strings_versions,   :user_id],
      [:votes,                          :user_id]
    ].each do |table, col|
      User.connection.update %(
        UPDATE #{table} SET `#{col}` = 0 WHERE `#{col}` = #{id}
      )
    end

    # Delete references to their one-user group.
    group = UserGroup.one_user(id)
    if group
      group_id = group.id
      [
        [:location_descriptions_admins,  :user_group_id],
        [:location_descriptions_readers, :user_group_id],
        [:location_descriptions_writers, :user_group_id],
        [:name_descriptions_admins,      :user_group_id],
        [:name_descriptions_readers,     :user_group_id],
        [:name_descriptions_writers,     :user_group_id],
        [:user_groups,                   :id]
      ].each do |table, col|
        User.connection.delete %(
          DELETE FROM #{table} WHERE `#{col}` = #{group_id}
        )
      end
    end

    # Delete their observations' attachments.
    ids = User.connection.select_values(%(
      SELECT id FROM observations WHERE user_id = #{id}
    )).map(&:to_s)
    if ids.any?
      ids = ids.join(",")
      [
        [:collection_numbers_observations, :observation_id],
        [:comments,                        :target_id, :target_type],
        [:herbarium_records_observations,  :observation_id],
        [:images_observations,             :observation_id],
        [:interests,                       :target_id, :target_type],
        [:namings,                         :observation_id],
        [:rss_logs,                        :observation_id],
        [:sequences,                       :observation_id],
        [:votes,                           :observation_id]
      ].each do |table, id_col, type_col|
        if type_col
          User.connection.delete %(
            DELETE FROM #{table}
            WHERE `#{id_col}` IN (#{ids}) AND `#{type_col}` = 'Observation'
          )
        else
          User.connection.delete %(
            DELETE FROM #{table}
            WHERE `#{id_col}` IN (#{ids})
          )
        end
      end
    end

    # Delete records they own, culminating in the user record itself.
    [
      [:api_keys,                       :user_id],
      [:articles,                       :user_id],
      [:collection_numbers,             :user_id],
      [:comments,                       :user_id],
      [:copyright_changes,              :user_id],
      [:donations,                      :user_id],
      [:external_links,                 :user_id],
      [:glossary_terms,                 :user_id],
      [:glossary_terms_versions,        :user_id],
      [:herbaria,                       :personal_user_id],
      [:herbaria_curators,              :user_id],
      [:herbarium_records,              :user_id],
      [:images,                         :user_id],
      [:image_votes,                    :user_id],
      [:interests,                      :user_id],
      [:location_descriptions_authors,  :user_id],
      [:location_descriptions_editors,  :user_id],
      [:name_descriptions_authors,      :user_id],
      [:name_descriptions_editors,      :user_id],
      [:notifications,                  :user_id],
      [:observations,                   :user_id],
      [:publications,                   :user_id],
      [:queued_emails,                  :user_id],
      [:queued_emails,                  :to_user_id],
      [:sequences,                      :user_id],
      [:species_lists,                  :user_id],
      [:user_groups_users,              :user_id],
      [:users,                          :id]
    ].each do |table, col|
      User.connection.delete %(
        DELETE FROM #{table} WHERE `#{col}` = #{id}
      )
    end
  end

  # Does user have any unshown naming notifications?
  # (I'm thoroughly confused about what role the observation plays in this
  # complicated set of pages. -JPH)
  def has_unshown_naming_notifications?(_observation = nil)
    result = false
    QueuedEmail.where(flavor: "QueuedEmail::NameTracking",
                      user_id: id).each do |q|
      _naming_id, notification_id, shown =
        q.get_integers([:naming, :notification, :shown])
      next unless shown.nil?
      notification = Notification.find(notification_id)
      next unless notification && notification.note_template
      result = true
      break
    end
    result
  end

  def remove_image(image)
    return unless self.image == image
    self.image = nil
    save
  end

  ##############################################################################

  # Encrypt a password.
  def self.sha1(pass) # :nodoc:
    Digest::SHA1.hexdigest("something__#{pass}__")
  end

  # Encrypted code used in autologin cookie and API authentication.
  def self.old_auth_code(password) # :nodoc:
    Digest::SHA1.hexdigest("SdFgJwLeR#{password}WeRtWeRkTj")
  end

  # This is a +before_create+ callback that encrypts the password before saving
  # the new user record.  (Not needed for updates because we use
  # change_password for that instead.)
  def crypt_password # :nodoc:
    unless password.blank?
      write_attribute("password", self.class.sha1(password))
    end
    write_attribute("auth_code", String.random(40))
  end

################################################################################

  private

  validate :user_requirements
  validate :check_password, on: :create
  validate :notes_template_forbid_other
  validate :notes_template_forbid_duplicates

  def user_requirements # :nodoc:
    if login.to_s.blank?
      errors.add(:login, :validate_user_login_missing.t)
    elsif login.length < 3 || login.size > 40
      errors.add(:login, :validate_user_login_too_long.t)
    elsif (other = User.find_by_login(login)) && (other.id != id)
      errors.add(:login, :validate_user_login_taken.t)
    end

    if password.to_s.present? && (password.length < 5 || password.size > 40)
      errors.add(:password, :validate_user_password_too_long.t)
    end

    if email.to_s.blank?
      errors.add(:email, :validate_user_email_missing.t)
    elsif email.size > 80
      errors.add(:email, :validate_user_email_too_long.t)
    end

    errors.add(:theme, :validate_user_theme_too_long.t) if theme.to_s.size > 40
    errors.add(:name, :validate_user_name_too_long.t) if name.to_s.size > 80
  end

  def check_password # :nodoc:
    unless password.blank?
      if password_confirmation.to_s.blank?
        errors.add(:password, :validate_user_password_confirmation_missing.t)
      elsif password != password_confirmation
        errors.add(:password, :validate_user_password_no_match.t)
      end
    end
  end

  def notes_template_forbid_other # :nodoc
    notes_template_bad_parts.each do |part|
      errors.add(:notes_template, :prefs_notes_template_no_other.t(part: part))
    end
  end

  def notes_template_forbid_duplicates # :nodoc
    return unless notes_template.present?
    squished = notes_template.split(",").map(&:squish)
    dups = squished.uniq.select { |part| squished.count(part) > 1 }
    dups.each do |dup|
      errors.add(:notes_template, :prefs_notes_template_no_dups.t(part: dup))
    end
  end

  def notes_template_bad_parts # :nodoc
    return [] unless notes_template.present?
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
  # :nodoc
  def notes_template_reserved_words
    [Observation.other_notes_part.downcase].concat(notes_other_translations)
  end

  # :nodoc
  def notes_other_translations
    %w(andere altro altra autre autres otra otras otro otros outros)
  end
end
