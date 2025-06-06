# frozen_string_literal: true

# Encapsulates a single user's iNatImport
#
# == Attributes
#
#  user::            user who initiated the iNat import
#  state::           state of the import
#  ended_at::        when the job was Done
#  token::           code, authenticity token, or JWT supplied by iNat
#  inat_ids::        string of id's of iNat obss to be imported
#  inat_username::   iNat login
#  import_all:       whether to import all of user's relevant iNat observations
#  importables::     # of importable observations
#  imported_count::  running count of iNat obss imported in the associated job
#  response_errors:: string of newline-separated error messages
#  log::             serialized log of inat import job
#
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

  def pending?
    %w[Authorizing Authenticating Importing].include?(state)
  end

  def add_response_error(error)
    response_errors << "#{error.class.name}: #{error.message}\n"
    save
  end

  def self.super_importers
    Project.find_by(title: "SuperImporters").user_group.users
  end
end
