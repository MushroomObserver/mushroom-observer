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
      @observation = nil
      return if unimportable?
      return if date_missing?
      return if already_imported?

      builder = create_mo_observation
      return unless @observation

      accumulate_counts(builder)
      finalize_import
    end

    private

    def unimportable?
      return false if @inat_obs.taxon_importable?

      log_with_response_error("Skipped #{@inat_obs[:id]} not importable")
      inat_import.add_ignored_obs(:not_importable)
      true
    end

    def date_missing?
      return false if @inat_obs.observed_on_present?

      log_with_response_error(
        "Skipped #{@inat_obs[:id]} #{:inat_observed_missing_date.l}"
      )
      inat_import.add_ignored_obs(:date_missing)
      true
    end

    # Last-line-of-defense check against duplicate imports.
    # Upstream filters (iNat-side `without_field` and the controller's
    # `clean_inat_ids`) miss observations whose back-link write to iNat
    # failed silently after a prior import, and the controller filter
    # is bypassed entirely on import-all runs. The import ExternalLink's
    # unique index (one import per target) is the actual race-safety
    # guarantee; this pre-check just keeps benign duplicates from emitting
    # noisy RecordNotUnique exceptions.
    def already_imported?
      return false unless ExternalLink.import.exists?(
        target_type: "Observation",
        external_site_id: inat_site.id,
        external_id: @inat_obs[:id].to_s
      )

      log("Skipped #{@inat_obs[:id]} already imported")
      inat_import.add_ignored_obs(:already_imported)
      true
    end

    # Cached iNaturalist ExternalSite for this importer instance — avoids
    # one find_by per imported observation across already_imported? and
    # the builder's import ExternalLink (#4299).
    def inat_site
      @inat_site ||= ExternalSite.inaturalist
    end

    def log_with_response_error(msg)
      log(msg)
      @inat_import.add_response_error(msg)
    end

    def create_mo_observation
      builder = Inat::MoObservationBuilder.new(
        inat_obs: @inat_obs, user: @user,
        import_others: @inat_import.import_others,
        external_site: inat_site,
        inat_import: @inat_import
      )
      @observation = builder.mo_observation
      builder
    rescue ActiveRecord::RecordNotUnique
      # The import ExternalLink's unique index caught a race between
      # simultaneous jobs after `already_imported?` returned false.
      # Treat the same as the pre-check skip.
      @observation = nil
      log("Skipped #{@inat_obs[:id]} already imported (race)")
      nil
    rescue StandardError => e
      @observation = nil
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
      update_inat_observation unless skip_inat_writeback?
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

    # Stamp the MO observation's URL onto the source iNat observation. Only
    # called when writing back: `finalize_import` gates this on
    # `skip_inat_writeback?` (skipped by default in development so a local
    # import never annotates a real iNat observation; production writes back,
    # and the test suite is isolated from iNat by WebMock). Admins can override
    # per import via a checkbox on the import form (InatImport#writeback).
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

    # Use cumulative moving average to update user's historical avg import time
    # (which is then used to estimate remaining time for the job).
    # https://en.wikipedia.org/wiki/Moving_average#Cumulative_moving_average
    def update_timings
      elapsed = @inat_import.last_obs_elapsed_time
      count = @inat_import.imported_count.to_i
      current_avg = @inat_import.avg_import_time.to_f
      new_avg = current_avg + (elapsed - current_avg) / count
      @inat_import.update(
        total_seconds: @inat_import.total_seconds.to_i + elapsed,
        avg_import_time: new_avg
      )
      @inat_import.reset_last_obs_start
    end

    def log(message)
      return unless job

      job.log(message)
    end
  end
end
