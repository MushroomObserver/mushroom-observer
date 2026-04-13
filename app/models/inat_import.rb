# frozen_string_literal: true

# Encapsulates a single user's iNatImport
#
# == Attributes
#
#  user::                  user who initiated the iNat import
#  state::                 state of the import
#  ended_at::              when the job was Done
#  token::                 token used to validate request; can be a code,
#                          authorization token, or JWT
#                          depending on the state of the import
#                          https://www.inaturalist.org/pages/api+reference#authorization_code_flow
#  inat_ids::              string of id's of iNat obss to be imported
#  inat_username::         iNat login of user whose obss are being imported
#                          Appended to iNat API query in order to generally
#                          an MO user from importing someone else's iNat obss
#  import_all:             whether to import all of user's relevant iNat obss
#  importables::           number of importable observations in job
#  imported_count::        running count of iNat obss imported in associated job
#  response_errors::       string of newline-separated error messages
#  total_imported_count::  historical count of iNat obss imported by this user
#  total_seconds::         all-time seconds this user spent importing iNat obss
#  avg_import_time         user's historical seconds per import
#  last_obs_start          when started importing a single iNat obs
#                          reset in InatImportsController#authorization_response
#                          and in Job after each observation import
#  cancel/canceled::       Did the user requested canceling the Job
#
# == Class Methods
#  super_importers         users who can import other users' iNat obss
#  super_importer?         is a given user a super_importer?

# == Methods
#  total_expected_time     total expected time for associated Job
#  last_obs_elapsed_time   time spent importing a single iNat obs
#  adequate_constraints?   enough constraints on which observations to import?
#
#
class InatImport < ApplicationRecord
  alias_attribute :canceled, :cancel # for readability, e.g., job.canceled?

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

  after_initialize :ensure_response_errors_initialized

  # Expected average import time if no user has ever imported anything
  # (Only gets used once.)
  BASE_AVG_IMPORT_SECONDS = 15

  # An import stuck in Importing state longer than this is assumed to have
  # crashed. Must match the schedule in config/recurring.yml.
  STUCK_THRESHOLD = 3.minutes

  # Are there enough constraints on which observations to import?
  # See also InatImportsController::Validators#adequately_constrained?
  # Need to make sure that the iNat API query has enough constrains so
  # that we don't import too many observations or, even worse,
  # all observations of all users.
  def adequate_constraints?
    return inat_username.present? unless import_others

    # Not-own superimporter: safe only if scoped to a username or a
    # specific ID list. Without either, import_all would fetch all
    # fungal/slime-mold observations across all iNat users.
    inat_username.present? || inat_ids.present?
  end

  def job_pending?
    %w[Authenticating Importing].include?(state)
  end

  # True if stuck in Importing state with no recent activity.
  # updated_at is touched after every observation import, so
  # no update in longer than STUCK_THRESHOLD indicates a crashed worker.
  def stuck?
    Importing? && ended_at.nil? && updated_at < STUCK_THRESHOLD.ago
  end

  def add_response_error(error)
    msg = if error.is_a?(::RestClient::Response)
            error.body
          elsif error.is_a?(String)
            error
          else
            error.message
          end
    self.response_errors += "#{msg}\n"
    save
  end

  # Users who can import others users' iNat observations
  def self.super_importers
    Project.find_by(title: "SuperImporters").user_group.users
  end

  def self.super_importer?(user)
    super_importers.include?(user)
  end

  # Total expected time for associated Job, in seconds.
  # Based on number of importable observations and user's historical
  # average import time.
  # If user has no import history, use system-wide average import time.
  # If no system-wide history, use BASE_AVG_IMPORT_SECONDS.
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

  def reset_last_obs_start
    update(last_obs_start: Time.now.utc)
  end

  def last_obs_elapsed_time
    return 0 unless last_obs_start

    Time.now.utc - last_obs_start
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

  def ensure_response_errors_initialized
    self.response_errors ||= ""
  end
end
