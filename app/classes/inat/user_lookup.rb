# frozen_string_literal: true

class Inat
  # An iNat user's public profile -- id, login and display name -- from
  # iNat's API, which takes a login in place of the numeric id. Nil when
  # iNat has no such user or can't be reached.
  #
  # A page render waits on this, so it gives up quickly, and a found
  # profile is cached briefly so a page and the job it starts agree.
  module UserLookup
    TIMEOUT = 5 # seconds
    CACHE_FOR = 1.hour

    def self.call(login)
      return nil if login.blank?

      Rails.cache.fetch("inat_user_lookup/#{login}", expires_in: CACHE_FOR,
                                                     skip_nil: true) do
        fetch(login)
      end
    end

    def self.fetch(login)
      response = Inat::APIRequest.new(nil).
                 request(path: "users/#{CGI.escape(login)}", timeout: TIMEOUT)
      JSON.parse(response.body)["results"]&.first&.
        slice("id", "login", "name")
    rescue RestClient::Exception, JSON::ParserError, SocketError => e
      Rails.logger.warn("iNat user lookup for #{login} failed: #{e.message}")
      nil
    end
  end
end
