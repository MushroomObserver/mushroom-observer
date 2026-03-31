# frozen_string_literal: true

class Inat
  # Import a page of parsed iNat API observation search results,
  # using Inat::Obs to parse each result and
  # Inat::MoObservationBuilder to create an MO Observation.
  class ObservationImporter
    include Inat::Constants

    attr_reader :inat_import, :user, :job,
                :unlicensed_obs_count, :skipped_images_count

    def initialize(inat_import, user, job = nil)
      @inat_import = inat_import
      @user = user
      @job = job
      @unlicensed_obs_count = 0
      @skipped_images_count = 0
    end

    def import_page(page)
      page["results"].each do |result|
        return false if inat_import.reload.canceled?

        import_one_result(JSON.generate(result))
      end
    end

    def import_one_result(result)
      @inat_obs = Inat::Obs.new(result)
      return if unimportable?
      return if date_missing?

      builder = create_mo_observation
      return unless @observation

      accumulate_counts(builder)
      finalize_import
    end

    private

    def unimportable?
      return false if @inat_obs.taxon_importable?

      log_with_response_error("Skipped #{@inat_obs[:id]} not importable")
      true
    end

    def date_missing?
      return false if @inat_obs.observed_on_present?

      log_with_response_error(
        "Skipped #{@inat_obs[:id]} #{:inat_observed_missing_date.l}"
      )
      true
    end

    def log_with_response_error(msg)
      log(msg)
      @inat_import.add_response_error(msg)
    end

    def create_mo_observation
      builder = Inat::MoObservationBuilder.new(
        inat_obs: @inat_obs, user: @user,
        import_others: @inat_import.import_others
      )
      @observation = builder.mo_observation
      builder
    rescue StandardError => e
      log_with_response_error(
        "Failed to import iNat #{@inat_obs[:id]}: #{e.message}"
      )
      nil
    end

    def accumulate_counts(builder)
      @unlicensed_obs_count += builder.unlicensed_obs
      @skipped_images_count += builder.skipped_images
    end

    def finalize_import
      update_inat_observation
      log("Imported iNat #{@inat_obs[:id]} as MO #{@observation.id}")
      increment_imported_counts
      update_timings
    rescue StandardError => e
      log_with_response_error(
        "Failed to finalize import of iNat #{@inat_obs[:id]}: #{e.message}"
      )
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
