# frozen_string_literal: true

require "json"

class Inat
  class URLBackfill
    # The pass's iNat traffic: searching for observations carrying the
    # "Mushroom Observer URL" field, and writing corrected values back.
    # Holds the pacing and the short-lived credential, so the walk
    # itself makes no API calls and tests can stand in for the whole
    # conversation.
    #
    # The stored credential is a long-lived OAuth access token (it lives
    # until revoked); iNat's API takes the 24h JWT minted from it at
    # /users/api_token. A pass spanning weeks outlives any one JWT, so a
    # 401 mints a fresh one and retries once. Searching needs no
    # credential.
    class Client
      include Inat::Constants

      PER_PAGE = 200 # iNat's maximum

      # Self-imposed pacing, within iNat's ~60 requests/minute guidance.
      WRITE_SLEEP = 1.0
      PAGE_SLEEP = 1.0

      # The value written always names production, since that is where
      # iNat's visitors follow the link to.
      TARGET_HOST = "https://mushroomobserver.org"

      # Raised when no usable credential is configured, or iNat rejects
      # the one that is: the pass cannot continue until someone
      # re-authorizes it.
      class AuthError < StandardError; end

      # Set on the server: `inat: { backfill_access_token: ... }` in the
      # production credentials, or INAT_BACKFILL_ACCESS_TOKEN in the
      # worker's environment. Solid Queue workers cache decrypted
      # credentials, so restart them -- not just Puma -- after editing.
      def self.configured_access_token
        ENV["INAT_BACKFILL_ACCESS_TOKEN"].presence ||
          Rails.application.credentials.inat&.backfill_access_token
      end

      def self.configured? = configured_access_token.present?

      def initialize(access_token: self.class.configured_access_token)
        @access_token = access_token
        raise(AuthError.new("no iNat OAuth access token configured")) if
          @access_token.blank?
      end

      # One page of observations carrying the field, newest first.
      def search(id_below: nil)
        body = Inat::APIRequest.new(nil).request(path: path(id_below)).body
        results = JSON.parse(body)["results"]
        pause(PAGE_SLEEP)
        results
      end

      # Returns the value written. RestClient errors from the PUT are
      # the caller's to count: one field value iNat rejects should not
      # end a run with thousands of others to get through.
      def write(ofv_id, mo_id)
        value = "#{TARGET_HOST}/obs/#{mo_id}"
        @retried = false
        put(ofv_id, value)
        pause(WRITE_SLEEP)
        value
      end

      def token = @token ||= mint_jwt

      private

      # A seam: tests stand in for the pacing rather than
      # waiting out a run.
      def pause(seconds) = sleep(seconds)

      def path(id_below)
        field = ERB::Util.url_encode(MO_URL_OBSERVATION_FIELD_NAME)
        path = "observations?field:#{field}=&order_by=id&order=desc" \
               "&per_page=#{PER_PAGE}"
        id_below ? "#{path}&id_below=#{id_below}" : path
      end

      def put(ofv_id, value)
        api.request(
          path: "observation_field_values/#{ofv_id}", method: :put,
          payload: { observation_field_value: { value: value } }
        )
      rescue RestClient::Unauthorized
        raise(AuthError.new("iNat rejected a freshly minted JWT")) if @retried

        @retried = true
        @token = nil
        @api = nil
        retry
      end

      def api = @api ||= Inat::APIRequest.new(token)

      def mint_jwt
        jwt = Inat::APIToken.new(
          app_id: nil, site: SITE, redirect_uri: nil, secret: nil
        ).trade_access_token_for_jwt_api_token(@access_token)
        raise(AuthError.new("iNat did not accept the OAuth access token")) if
          jwt.blank?

        jwt
      rescue RestClient::ExceptionWithResponse => e
        raise(AuthError.new("minting an iNat JWT failed: #{e.message}"))
      end
    end
  end
end
