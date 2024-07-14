# frozen_string_literal: true

# Encapsulates a single user's iNatImport
#
# == Attributes
#
#  user::
#  state::  state of the import
#  token::  JSON Web Token (JWT) supplied by iNat
#
# == methods
#
class InatImport < ApplicationRecord
  enum state:
  {
    Unstarted: 0,
    Authorizing: 1, # waiting for User to authorize MO to access iNat data
    Authenticating: 2,
    Importing: 3,
    Done: 4
  }

  belongs_to :user
end
