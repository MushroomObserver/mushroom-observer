# frozen_string_literal: true

# Encapsulates a single user's iNatImport
# and glues Job and Track to each other (and to Import)
#
# == Attributes
#
#  user::                  user who initiated the iNat import
#  state::                 state of the import
#  ended_at::              when the job was Done
#  token::                 code, authenticity token, or JWT supplied by iNat
#  inat_ids::              string of id's of iNat obss to be imported
#  inat_username::         this user's iNat login
#  import_all:             whether to import all of user's relevant iNat obss
#  importables::           number of importable observations in job
#  imported_count::        running count of iNat obss imported in associated job
#  response_errors::       string of newline-separated error messages
#  total_imported_count::  historical count of iNat obss imported by this user
#  total_seconds::         all-time seconds this user spent importing iNat obss
#
# == Methods
#  total_expected_time     total expected time for associated Job
class InatImport < ApplicationRecord
  enum :state, {
    Unstarted: 0,
    # waiting for User to authorize MO to access iNat data
    Authorizing: 1,
    # trading iNat authorization code for an authentication token
    Authenticating: 2,
    Importing: 3,
    Done: 4
  }

  belongs_to :user
  has_many :inat_import_job_trackers, dependent: :delete_all

  serialize :log, type: Array, coder: YAML

  # Expected average import time if no user has ever imported anything
  # (Only gets used once.)
  BASE_AVG_IMPORT_SECONDS = 15

  def pending?
    %w[Authorizing Authenticating Importing].include?(state)
  end

  def add_response_error(error)
    response_errors << "#{error.class.name}: #{error.message}\n"
    save
  end

  # Users who can import others users' iNat observations
  def self.super_importers
    Project.find_by(title: "SuperImporters").user_group.users
  end

  def total_expected_time
    importables * initial_avg_import_seconds
  end

  def initial_avg_import_seconds
    if user_import_history?
      personal_initial_avg_import_seconds
    elsif system_import_history?
      system_initial_avg_import_seconds
    else
      BASE_AVG_IMPORT_SECONDS
    end
  end

  #########

  private

  def user_import_history?
    total_imported_count.to_i.positive?
  end

  def personal_initial_avg_import_seconds
    total_seconds / total_imported_count
  end

  def system_import_history?
    InatImport.sum(:total_imported_count).to_i.positive?
  end

  def system_initial_avg_import_seconds
    InatImport.sum(:total_seconds) / InatImport.sum(:total_imported_count)
  end
end
