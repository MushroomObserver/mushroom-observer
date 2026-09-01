# frozen_string_literal: true

class Inat
  class ObservationImporter
    # Stamps the MO observation's URL back onto the source iNat
    # observation, with retry/backoff for transient failures. Mixed into
    # Inat::ObservationImporter.
    module Writeback
      include Inat::Constants

      # Transient iNat/AWS failures worth retrying with backoff before
      # giving up on the writeback (and, ultimately, on the just-created
      # MO Observation).
      RETRYABLE_WRITEBACK_ERRORS = [
        RestClient::ServiceUnavailable, RestClient::TooManyRequests,
        RestClient::BadGateway, RestClient::GatewayTimeout,
        RestClient::RequestTimeout, RestClient::ServerBrokeConnection
      ].freeze
      MAX_WRITEBACK_RETRIES = 3       # on a retryable writeback failure
      WRITEBACK_RETRY_BASE_SLEEP = 2  # seconds; doubles each retry (2, 4, 8)
      MAX_RETRY_AFTER_WAIT = 8        # iNat's Retry-After honored up to this

      private

      # Write the MO observation URL to the iNat observation.
      # Called only when writing back: `finalize_import` gates this on
      # `skip_inat_writeback?` (skipped by default in development).
      def update_inat_observation
        update_mushroom_observer_url_field
        sleep(1) # Avoid hitting iNat API rate limits
      end

      def skip_inat_writeback?
        return Rails.env.development? if @inat_import.writeback_default?

        @inat_import.writeback_skip?
      end

      def update_mushroom_observer_url_field
        update_inat_observation_field(
          observation_id: @inat_obs[:id],
          field_id: MO_URL_OBSERVATION_FIELD_ID,
          value: "#{MO.http_domain}/#{@observation.id}"
        )
      end

      def update_inat_observation_field(observation_id:, field_id:, value:,
                                        attempt: 1)
        payload = { observation_field_value: { observation_id: observation_id,
                                               observation_field_id: field_id,
                                               value: value } }
        Inat::APIRequest.new(@inat_import.token).
          request(method: :post,
                  path: "observation_field_values",
                  payload: payload)
      rescue *RETRYABLE_WRITEBACK_ERRORS => e
        retry_or_raise_writeback(e, payload, attempt)
      rescue ::RestClient::ExceptionWithResponse => e
        log_and_raise_writeback_error(e, payload)
      end

      # iNat can return a transient error (503, etc.) after the field value
      # was persisted. Confirm before retrying or giving up, so a false
      # error doesn't needlessly retry or back out the just-created MO
      # Observation.
      def retry_or_raise_writeback(error, payload, attempt)
        ofv = payload[:observation_field_value]
        return if field_actually_written?(ofv[:observation_id],
                                          ofv[:observation_field_id],
                                          ofv[:value])

        if attempt <= MAX_WRITEBACK_RETRIES
          backoff_for_writeback_retry(error, attempt)
          return update_inat_observation_field(
            observation_id: ofv[:observation_id],
            field_id: ofv[:observation_field_id],
            value: ofv[:value], attempt: attempt + 1
          )
        end

        log_and_raise_writeback_error(error, payload)
      end

      def field_actually_written?(observation_id, field_id, value)
        raw_obs = fetch_inat_observation(observation_id)
        fields = Inat::Obs.new(JSON.generate(raw_obs)).inat_obs_fields
        fields&.find { |field| field[:field_id] == field_id }&.dig(:value) ==
          value
      rescue StandardError
        false
      end

      def fetch_inat_observation(observation_id)
        response = Inat::APIRequest.new(@inat_import.token).
                   request(path: "observations/#{observation_id}")
        JSON.parse(response.body, symbolize_names: true)[:results]&.first || {}
      end

      def backoff_for_writeback_retry(error, attempt)
        backoff = retry_after_seconds(error) ||
                  WRITEBACK_RETRY_BASE_SLEEP * (2**(attempt - 1))
        warn("  iNat writeback #{error.class} on observation field; " \
             "retry #{attempt}/#{MAX_WRITEBACK_RETRIES} in #{backoff}s")
        sleep(backoff)
      end

      # Honor iNat's Retry-After if within this class's retry budget;
      # Else fall back to the doubling backoff.
      def retry_after_seconds(error)
        headers = error.response&.headers
        seconds = headers && headers[:retry_after]&.to_i
        return nil unless seconds&.positive? && seconds <= MAX_RETRY_AFTER_WAIT

        seconds
      end

      def log_and_raise_writeback_error(error, payload)
        error_json = { error: error.http_code, payload: payload }.to_json
        log_with_response_error(error_json)
        raise(error)
      end
    end
  end
end
