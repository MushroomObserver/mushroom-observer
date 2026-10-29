# frozen_string_literal: true

class Inat
  class ObservationImporter
    # Stamping the new MO observation back onto the source iNat
    # observation, with the retry budget a transient iNat failure needs
    # (#4589).
    module Writeback
      private

      # Stamp the MO observation's URL onto the source iNat observation. Only
      # called when writing back: `finalize_import` gates this on
      # `skip_inat_writeback?` (skipped by default in development so a local
      # import never annotates a real iNat observation; production writes back,
      # and the test suite is isolated from iNat by WebMock). Admins can
      # override per import via a checkbox on the import form
      # (InatImport#writeback).
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
          field_id: Inat::Constants::MO_URL_OBSERVATION_FIELD_ID,
          value: @observation.show_url
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

      # Verify by the field_id passed in, not a field hard-coded to the MO
      # URL field -- update_inat_observation_field's signature is generic,
      # so this stays correct if it's called for another observation field.
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

      # Honor iNat's Retry-After when it's within our own retry budget;
      # otherwise fall back to our own doubling backoff so a large
      # server-suggested wait can't stall the whole import.
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
