# frozen_string_literal: true

# Encapsulates a single user's iNatImport
#
# == Attributes
#
#  user::             user who initiated the iNat import
#  state::            state of the import
#  token::            authenticity token supplied by iNat
#  inat_ids::         string representing the iNat obss to be imported
#  inat_username::    iNat login of iNat user whose obss are to be imported
#  import_all:        import all a user's relevant iNat observations?
#  field_slip_code::  field_slip_code (only if importing a single obs)
#  project_id::       id of Project (overrides Field Slip's Project)
#                     (only if importing a single obs)
class InatImport < ApplicationRecord
  enum state:
  {
    Unstarted: 0,
    # waiting for User to authorize MO to access iNat data
    Authorizing: 1,
    # trading iNat authorization code for an authentication token
    Authenticating: 2,
    Importing: 3,
    Done: 4
  }

  belongs_to :user
end
