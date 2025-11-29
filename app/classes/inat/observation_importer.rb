# frozen_string_literal: true

class Inat
  # Import a page of parsed iNat API observation search results,
  # using Inat::Obs to parse each result and
  # Inat::MoObservationBuilder to create an MO Observation.
  class ObservationImporter
    include Inat::Constants

    attr_reader :inat_import, :user, :job

    def initialize(inat_import, user, job = nil)
      @inat_import = inat_import
      @user = user
      @job = job
    end

    def import_page(page)
      page["results"].each do |result|
        return false if inat_import.reload.canceled?

        import_one_result(JSON.generate(result))
      end
    end

    def import_one_result(result)
      @inat_obs = Inat::Obs.new(result)
      return unimportable unless @inat_obs.taxon_importable?
      return date_missing if @inat_obs.observed_on_missing?

      create_mo_observation
      return unless @observation

      finalize_import
    end

    private

    def unimportable
      log_with_response_error("Skipped #{@inat_obs[:id]} not importable")
    end

    def date_missing
      log_with_response_error(
        "Skipped #{@inat_obs[:id]} #{:inat_observed_missing_date.l}"
      )
    end

    def log_with_response_error(msg)
      log(msg)
      @inat_import.add_response_error(msg)
    end

    def create_mo_observation
      builder = Inat::MoObservationBuilder.new(inat_obs: @inat_obs, user: @user)
      @observation = builder.mo_observation
    rescue StandardError => e
      log_with_response_error(
        "Failed to import iNat #{@inat_obs[:id]}: #{e.message}"
      )
      nil
    end

    def finalize_import
      update_inat_observation
      log("Imported iNat #{@inat_obs[:id]} as MO #{@observation.id}")
      increment_imported_counts
      update_timings
    rescue StandardError
      # Error already logged by the method that raised it
      @observation&.destroy
      nil
    end

    def update_inat_observation
      update_mushroom_observer_url_field
      sleep(1) # Avoid hitting iNat API rate limits
    end

    def update_mushroom_observer_url_field
      update_inat_observation_field(
        observation_id: @inat_obs[:id],
        field_id: MO_URL_OBSERVATION_FIELD_ID,
        value: "#{MO.http_domain}/#{@observation.id}"
      )
    end

    def update_inat_observation_field(observation_id:, field_id:, value:)
      payload = { observation_field_value: { observation_id: observation_id,
                                             observation_field_id: field_id,
                                             value: value } }
      Inat::APIRequest.new(@inat_import.token).
        request(method: :post,
                path: "observation_field_values",
                payload: payload)
    rescue ::RestClient::ExceptionWithResponse => e
      error = { error: e.http_code, payload: payload }.to_json
      log_with_response_error(error)
      raise(e)
    end

    def increment_imported_counts
      @inat_import.increment!(:imported_count)
      @inat_import.increment!(:total_imported_count)
    end

    def update_timings
      total_seconds =
        @inat_import.total_seconds.to_i + @inat_import.last_obs_elapsed_time
      @inat_import.update(
        total_seconds: total_seconds,
        avg_import_time: total_seconds / (@inat_import.imported_count || 1)
      )
      @inat_import.reset_last_obs_start
    end

    def log(message)
      return unless job

      job.log(message)
    end
  end
end
