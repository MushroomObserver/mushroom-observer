require 'digest/sha1'

################################################################################
#
#  Model describing a user.  Pretty much just a big container.  Properties:
#
#  1. has login, password, and email (standard login stuff)
#  2. must be verified (via email sent after signing up)
#  3. has a contribution score (see SiteData)
#  4. can own a whole bunch of things (e.g. Observation's, Name's, Vote's, etc.)
#  5. has profile (e.g. name, location, notes, mugshot)
#  6. has preferences (e.g. theme, layout, etc.)
#  7. can be a member of various user groups
#  8. can be an author or editor on Name's or Observation's
#
#  Login is handled by lib/login_system.rb, a third-party package that we've
#  modified slightly.  It is enforced by adding <tt>before_filter
#  :login_required</tt> filters to the controllers.  We now support autologin
#  or "remember me" login via a simple cookie and the application-wide
#  <tt>before_filter :autologin</tt> filter in ApplicationController.
#
#  Contribution score is just a cache.  It is very carefully kept up to date by
#  several callbacks in Observation, SpeciesList, and
#  active_record_extensions.rb that modify it every time the user creates or
#  destroys an object.  It is also refreshed whenever anyone views the user's
#  summary page, just in case the callbacks ever fail.
#
#  It looks like there might be something funky to do with QueuedEmail, as
#  well, but I haven't looked at that code at all yet.
#
#  Public:
#    User.authenticate(login, pass)  Verify username/password.
#    auth_code                       Code used to verify autologin cookie and POSTs in database API.
#
#    change_password(string)         Set the appropriate attributes.
#    change_email(string)            Except for change_password() these are all
#    change_name(string)             equivalent to saying "user.blah = blah".
#    change_theme_id(theme_id)
#    change_rows(integer)
#    change_columns(integer)
#
#    unique_text_name()              Return "First Last (login)".
#    legal_name()                    Return "First Last".
#    find_theme                      Return preferred theme.
#    remember_me?                    Does user want us to automatically log them in via cookie?
#    watching?(object)               Is user watching an object?
#    ignoring?(object)               Is user watching an object?
#
#  Protected:
#    User.sha1(string)               Encrypt a string and return it.
#    crypt_password                  Encrypt password attribute.
#
#  Validates:
#    username must be from 3 to 40 characters and unique
#    password must be from 5 to 40 characters and confirmed
#    must have email
#
#  Other Magic:
#    password attribute is encrypted before object is created
#
################################################################################

class User < ActiveRecord::Base
  has_many :comments
  has_many :interests
  has_many :images
  has_many :observations
  has_many :species_lists
  has_many :names
  has_many :past_names
  has_many :namings
  has_many :votes
  has_many :test_add_image_logs
  has_many :locations
  has_many :queued_emails
  has_many :to_emails, :class_name => "QueuedEmail", :foreign_key => "to_user_id"
  has_many :notifications
  has_many :reviewed_images, :class_name => "Image", :foreign_key => "reviewer_id"
  has_many :reviewed_names, :class_name => "Name", :foreign_key => "reviewer_id"
  has_many :projects

  has_and_belongs_to_many :user_groups
  has_and_belongs_to_many :authored_names, :class_name => "Name", :join_table => "authors_names"
  has_and_belongs_to_many :edited_names, :class_name => "Name", :join_table => "editors_names"
  has_and_belongs_to_many :authored_locations, :class_name => "Location", :join_table => "authors_locations"
  has_and_belongs_to_many :edited_locations, :class_name => "Location", :join_table => "editors_locations"

  belongs_to :license       # user's default license
  belongs_to :image         # mug shot
  belongs_to :location      # primary location

  # This causes the data structure in user.bonuses to be serialized automatically
  # with YAML and stored in the database as a plain old text string.
  serialize :bonuses

  # Used to let user enter location by name in prefs form.
  attr_accessor :place_name

  # Used to let user enter password confirmation when signing up or changing password.
  attr_accessor :password_confirmation

  def self.authenticate(login, pass)
    find(:first, :conditions => ["login = ? AND password = ?", login, sha1(pass)])
  end

  # Code used to authenticate via cookie or XML request.
  def auth_code
    protected_auth_code
  end

  def change_password(pass)
    if pass != ''
      update_attribute "password", self.class.sha1(pass)
    end
  end

  def unique_text_name()
    if self.name
      sprintf("%s (%s)", self.name, self.login)
    else
      self.login
    end
  end

  def legal_name()
    if self.name && self.name != ''
      self.name
    else
      self.login
    end
  end

  def percent_complete()
    max = 3
    result = 0
    if self.notes && self.notes != ""
      result += 1
    end
    if self.location_id
      result += 1
    end
    if self.image_id
      result += 1
    end
    result * 100 / max
  end

  def in_group(group_name)
    result = false
    for g in self.user_groups
      if g.name == group_name
        result = true
        break
      end
    end
    return result
  end

  def remember_me?
    self.remember_me
  end

  def watching?(object)
    !interests.select {|i| i.state && i.object == object}.empty?
  end

  def ignoring?(object)
    !interests.select {|i| !i.state && i.object == object}.empty?
  end

  protected

  def self.sha1(pass)
    # Digest::SHA1.hexdigest("change-me--#{pass}--")
    Digest::SHA1.hexdigest("something__#{pass}__")
  end

  def protected_auth_code
    Digest::SHA1.hexdigest("SdFgJwLeR#{self.password}WeRtWeRkTj")
  end

  before_create :crypt_password

  def crypt_password
    write_attribute("password", self.class.sha1(password))
  end

  protected

  def validate # :nodoc:
    if self.login.to_s.blank?
      errors.add(:login, :validate_user_login_missing.t)
    elsif self.login.length < 3 or self.login.length > 40
      errors.add(:login, :validate_user_login_too_long.t)
    elsif (other = User.find_by_login(self.login)) && (other.id != self.id)
      errors.add(:login, :validate_user_login_taken.t)
    end

    if self.password.to_s.blank?
      errors.add(:password, :validate_user_password_missing.t)
    elsif self.password.length < 5 or password.length > 40
      errors.add(:password, :validate_user_password_too_long.t)
    end

    if self.email.to_s.blank?
      errors.add(:email, :validate_user_email_missing.t)
    elsif self.email.length > 80
      errors.add(:email, :validate_user_email_too_long.t)
    end

    if self.theme.to_s.length > 40
      errors.add(:theme, :validate_user_theme_too_long.t)
    end
    if self.name.to_s.length > 80
      errors.add(:name, :validate_user_name_too_long.t)
    end
  end

  def validate_on_create # :nodoc:
    if self.password_confirmation.to_s.blank?
      errors.add(:password, :validate_user_password_confirmation_missing.t)
    elsif self.password != self.password_confirmation
      errors.add(:password, :validate_user_password_no_match.t)
    end
  end
end
