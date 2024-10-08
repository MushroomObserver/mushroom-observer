# frozen_string_literal: true

# Encapsulates a single user's iNatImport
#
# == Attributes
#
#  user::            user who initiated the iNat import
#  state::           state of the import
#  token::           code, authenticity token, or JWT supplied by iNat
#  inat_ids::        string of id's of iNat obss to be imported
#  inat_username::   iNat login
#  import_all:       whether to import all of user's relevant iNat observations
#  importables::     # of importable observations
#  imported_count::  running count of iNat obss imported in the associated job
#  response_errors:: string of newline-separated error messages
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

  def add_response_error(response)
    # internal non-Ruby messages. Ex: { status: 401, body: "error message" }
    if response.is_a?(Hash)
      # for internal messages to be displayed as erros in tracker show
      # Ex: { status: 401, body: "error message" }
      code = response[:status]
      body_text = response[:body]
    else
      code = response.code
      begin
        doc = Nokogiri::HTML(response.body)
        body_text = doc.at("body").text.strip
      rescue StandardError
        body_text == ""
      end
    end

    response_errors << "#{code} #{body_text}\n"
    save
  end
end
