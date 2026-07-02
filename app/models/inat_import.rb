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
#  importables::           observations queued for the *current* job run; reset
#                          by the job from the iNat API total_results on start.
#                          Used by estimated_remaining_time.
#  total_importables::     estimated count recorded at confirm time; stable
#                          across re-runs (job only sets it as a fallback if
#                          blank). Used by total_expected_time for the ETA.
#                          Differs from importables when the API count diverges
#                          from the confirm-step estimate (result set changed
#                          between confirm and import).
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

  # Whether to stamp the MO link back onto the source iNat observation.
  # `default` defers to the environment (skip in development, write back
  # in production); admins can override per import via `skip`/`force`.
  enum :writeback, {
    default: 0,
    skip: 1,
    force: 2
  }, prefix: true

  belongs_to :user
  has_many :observations, dependent: :nullify

  serialize :log, type: Array, coder: YAML
  serialize :date_missing_inat_ids, coder: JSON
  serialize :license_added_inat_ids, coder: JSON

  after_update_commit lambda { |inat_import|
    html = ApplicationController.renderer.render(
      Views::Controllers::InatImports::Status.new(inat_import: inat_import)
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      [inat_import.user, :inat_import],
      target: "inat_import_#{inat_import.id}",
      html: html
    )
  }
  after_initialize :ensure_response_errors_initialized

  # Expected average import time if no user has ever imported anything
  # (Only gets used once.)
  BASE_AVG_IMPORT_SECONDS = 15

  # Hard cap on observations imported per InatImport run.
  MAX_IMPORTABLE = 2_500

  # An import stuck in Importing state longer than this is assumed to have
  # crashed. Must match the schedule in config/recurring.yml.
  STUCK_THRESHOLD = 3.minutes

  scope :stuck, lambda {
    where(state: "Importing", ended_at: nil).
      where(updated_at: ...STUCK_THRESHOLD.ago)
  }

  # An import that never completed the OAuth authorization handshake is
  # assumed abandoned after this long. Generous on purpose — a user won't
  # take an hour to authorize on iNat, but might take a couple of minutes.
  ABANDONED_THRESHOLD = 1.hour

  scope :abandoned, lambda {
    where(state: %w[Authorizing Authenticating]).
      where(updated_at: ...ABANDONED_THRESHOLD.ago)
  }

  # Are there enough constraints on which observations to import?
  # See also InatImportsController::Validators#adequately_constrained?
  # Need to make sure that the iNat API query has enough constrains so
  # that we don't import too many observations or, even worse,
  # all observations of all users.
  def adequate_constraints?
    return inat_username.present? unless import_others

    # Not-own superimporter: safe only if scoped to a username, a
    # specific ID list, or a URL query. Without any of these, import_all
    # would fetch all fungal/slime-mold observations across all iNat users.
    inat_username.present? || inat_ids.present? || inat_url.present?
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

  def add_ignored_obs(reason, inat_id: nil)
    case reason
    when :not_importable   then increment!(:ignored_not_importable_count)
    when :date_missing     then append_date_missing(inat_id)
    when :already_imported then increment!(:ignored_already_imported_count)
    else raise(ArgumentError.new("Unknown ignored reason: #{reason.inspect}"))
    end
  end

  def add_license_added_obs(inat_id:)
    reload
    update!(license_added_inat_ids: license_added_inat_ids + [inat_id])
  end

  def reached_import_cap?
    imported_count.to_i >= MAX_IMPORTABLE
  end

  def ignored_total_count
    ignored_not_importable_count.to_i +
      ignored_date_missing_count.to_i +
      ignored_already_imported_count.to_i
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
    total_importables.to_i * initial_avg_import_seconds
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

  def elapsed_time
    return 0 unless started_at

    end_time = Done? && ended_at ? ended_at : Time.zone.now
    (end_time - started_at).to_i
  end

  def estimated_remaining_time
    return 0 if Done?
    return nil unless total_importables.to_i.positive? && started_at
    return total_expected_time if imported_count.to_i.zero?

    [extrapolated_remaining_time, 0].max
  end

  # Observed rate (elapsed per imported obs) times obs still to import, so
  # the estimate tracks real progress instead of a fixed up-front guess.
  def extrapolated_remaining_time
    remaining = total_importables.to_i - imported_count.to_i
    (remaining * elapsed_time.to_f / imported_count).round
  end

  #########

  private

  def user_import_history?
    InatImport.where(user: user).sum(:total_imported_count).to_i.positive?
  end

  def personal_initial_avg_import_seconds
    scope = InatImport.where(user: user)
    scope.sum(:total_seconds) / scope.sum(:total_imported_count)
  end

  def system_import_history?
    InatImport.sum(:total_imported_count).to_i.positive?
  end

  def system_initial_avg_import_seconds
    InatImport.sum(:total_seconds) / InatImport.sum(:total_imported_count)
  end

  def ensure_response_errors_initialized
    self.response_errors ||= ""
    self.date_missing_inat_ids ||= []
    self.license_added_inat_ids ||= []
  end

  def append_date_missing(inat_id)
    reload
    self.ignored_date_missing_count = ignored_date_missing_count.to_i + 1
    self.date_missing_inat_ids = date_missing_inat_ids + [inat_id].compact
    save!
  end
end
