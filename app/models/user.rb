# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'digest/sha1'

# Public:
#   User.authenticate(login, pass)  Verify username/password.
#
#   change_password(string)         Set the appropriate attributes.
#   change_email(string)            Except for change_password() these are all
#   change_name(string)             equivalent to saying "user.blah = blah".
#   change_theme_id(theme_id)
#   change_rows(integer)
#   change_columns(integer)
#
#   unique_text_name()              Return "First Last (login)".
#   legal_name()                    Return "First Last".
#   find_theme                      Return preferred theme.
#   remember_me?                    Does user want us to automatically log them in via cookie?
#
# Protected:
#   User.sha1(string)               Encrypt a string and return it.
#   crypt_password                  Encrypt password attribute.
#
# Validates:
#   username must be from 3 to 40 characters, and unique
#   password must be from 5 to 40 characters, and confirmed
#   must have email and theme
#
# Other Magic:
#   password attribute is encrypted before object is created

# this model expects a certain database layout and its based on the name/login pattern.
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
  belongs_to :license

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
  validates_uniqueness_of :login, :on => :create
  validates_confirmation_of :password, :on => :create
end
