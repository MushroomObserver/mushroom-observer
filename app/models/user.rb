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
  
  belongs_to :license       # user's default license
  belongs_to :image         # mug shot
  belongs_to :location      # primary location

  # Used to let user enter location by name in prefs form.
  attr_accessor :place_name

  def self.authenticate(login, pass)
    find(:first, :conditions => ["login = ? AND password = ?", login, sha1(pass)])
  end

  def change_password(pass)
    if pass != ''
      update_attribute "password", self.class.sha1(pass)
    end
  end

  def change_email(email)
    self.email = email
  end

  def change_name(name)
    self.name = name
  end

  def change_theme(theme)
    self.theme = theme
  end

  def change_rows(rows)
    self.rows = rows
  end

  def change_columns(columns)
    self.columns = columns
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

  # This should become a database field
  def mailing_address()
    "[mailing address]"
  end
  
  def remember_me?
    self.remember_me
  end

  protected

  def self.sha1(pass)
    # Digest::SHA1.hexdigest("change-me--#{pass}--")
    Digest::SHA1.hexdigest("something__#{pass}__")
  end

  before_create :crypt_password

  def crypt_password
    write_attribute("password", self.class.sha1(password))
  end

  validates_length_of :login, :within => 3..40
  validates_length_of :password, :within => 5..40
  validates_presence_of :login, :password, :email
  validates_presence_of :password_confirmation, :on => :create
  validates_uniqueness_of :login
  validates_confirmation_of :password, :on => :create
end
