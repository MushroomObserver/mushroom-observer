# frozen_string_literal: true

class Inat
  # An iNat user's public profile -- id, login and display name -- from
  # iNat's API, which takes a login in place of the numeric id. Nil when
  # iNat has no such user or can't be reached.
  module UserLookup
    def self.call(login)
      return nil if login.blank?

      response = Inat::APIRequest.new(nil).
                 request(path: "users/#{CGI.escape(login)}")
      JSON.parse(response.body)["results"]&.first&.
        slice("id", "login", "name")
    rescue RestClient::Exception, JSON::ParserError, SocketError => e
      Rails.logger.warn("iNat user lookup for #{login} failed: #{e.message}")
      nil
    end
  end
end
