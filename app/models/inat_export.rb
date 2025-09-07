# frozen_string_literal: true

# Encapsulates a single user's iNatExport
#
# == Attributes
#
#  user::                  user who initiated the iNat export
#  state::                 state of the export
#  ended_at::              when the job was Done
#  token::                 token used to validate request; can be a code,
#                          authorization token, or JWT
#                          depending on the state of the export
#                          https://www.inaturalist.org/pages/api+reference#authorization_code_flow
#  mo_ids::                array of id's of MO Observations to be exported
#  exportables::           number of exportable observations in job
#  exported_count::        running count of MO obss exported in associated job
#  response_errors::       string of newline-separated error messages
#  total_exported_count::  historical count of MO obss exported by this user
#  total_seconds::         all-time seconds this user spent exporting MO obss
#  avg_export_time         user's historical seconds per export
#  last_obs_start          when started exporting a single MO obs
#                          reset in InatExportsController#authorization_response
#                          and in Job after each observation export
#  cancel/canceled::       Did the user requested canceling the Job
#
# == Methods
#  add_response_error      add an error message to response_errors
#  adequate_constraints?   enough constraints on which observations to export?
#  initial_avg_export_seconds  estimated average time to export a single MO obs#
#  job_pending?            is the associated Job still running?
#  last_obs_elapsed_time   time spent exporting a single MO obs
#  reset_last_obs_start    set last_obs_start to current time
#  total_expected_time     total expected time for associated Job
#
class InatExport < ApplicationRecord
  alias_attribute :canceled, :cancel # for readability, e.g., job.canceled?

  enum :state, {
    Unstarted: 0,
    # waiting for User to authorize MO to access iNat data
    Authorizing: 1,
    # trading iNat authorization code for an authentication token
    Authenticating: 2,
    Exporting: 3,
    Done: 4
  }

  belongs_to :user
  has_many :inat_export_job_trackers, dependent: :delete_all

  serialize :log, type: Array, coder: YAML

  # Expected average export time if no user has ever exported anything
  # (Only gets used once.)
  BASE_AVG_EXPORT_SECONDS = 15

  def job_pending?
    %w[Authorizing Authenticating Exporting].include?(state)
  end

  def add_response_error(error)
    msg = if error.is_a?(String)
            error
          elsif error.is_a?(::RestClient::Response)
            error.body
          else
            error.message
          end
    response_errors << "#{msg}\n"
    save
  end

  def total_expected_time
    exportables * initial_avg_export_seconds
  end

  def initial_avg_export_seconds
    if user_export_history?
      personal_initial_avg_export_seconds
    elsif system_export_history?
      system_initial_avg_export_seconds
    else
      BASE_AVG_EXPORT_SECONDS
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

  def personal_initial_avg_export_seconds
    total_seconds / total_exported_count
  end

  def system_export_history?
    InatExport.sum(:total_exported_count).to_i.positive?
  end

  def system_initial_avg_export_seconds
    InatExport.sum(:total_seconds) / InatExport.sum(:total_exported_count)
  end
end
