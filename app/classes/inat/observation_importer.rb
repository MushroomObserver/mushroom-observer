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
      return if unlicensed_other?
      return if already_linked?
      return if crosslinked_to_live_mo_obs?

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
      inat_import.add_ignored_obs(:date_missing, inat_id: @inat_obs[:id])
      true
    end

    # Safety net for import-others. This check is what actually stops an
    # unlicensed observation belonging to another iNat user from being
    # imported. Own-obs imports are never gated here.
    def unlicensed_other?
      return false unless inat_import.import_others
      return false if @inat_obs[:license_code].present?

      log("Skipped #{@inat_obs[:id]} unlicensed (import-others)")
      inat_import.add_ignored_obs(:unlicensed)
      true
    end

    # The real duplicate check: any typed iNat ExternalLink for this iNat
    # obs (import / mirror / copy / remote_manual / manual) means it already
    # corresponds to an MO observation, so importing it would create a
    # duplicate. With #4565's materialization the link set is complete, so
    # this MO-side check is what actually stops a duplicate — the iNat-side
    # `without_field` filter only trims how many observations iNat sends
    # back (and it's skipped entirely for explicit id lists and recheck_all
    # runs). The import ExternalLink's unique index (one import per target)
    # is still what prevents a duplicate if two imports race each other;
    # this check just keeps that race from surfacing as a noisy
    # RecordNotUnique exception.
    def already_linked?
      return false unless ExternalLink.exists?(
        target_type: "Observation",
        external_site_id: inat_site.id,
        external_id: @inat_obs[:id].to_s
      )

      log("Skipped #{@inat_obs[:id]} already linked to an MO observation")
      inat_import.add_ignored_obs(:already_imported)
      true
    end

    # The iNat obs carries an MO URL (field 5005) with no MO-side link — a
    # cross-reference hand-set on iNat. When the MO obs is alive,
    # materialize the missing remote_manual link (#4565) and skip the
    # import. A blank, dead (MO obs deleted), or unparseable value blocks
    # nothing: the obs is importable again.
    def crosslinked_to_live_mo_obs?
      mo_obs = live_crosslinked_mo_obs
      return false unless mo_obs

      link = create_crosslink(mo_obs)
      outcome = link ? "recorded the link" : "failed to record the link"
      log("Skipped #{@inat_obs[:id]} cross-referenced on iNat " \
          "to MO #{mo_obs.id}; #{outcome}")
      inat_import.add_ignored_obs(:already_imported)
      true
    end

    def live_crosslinked_mo_obs
      value = @inat_obs.mo_url_field_value
      return nil if value.blank?

      mo_obs_id = value[MO_URL_FIELD_VALUE_ID_RE, 1]
      return nil unless mo_obs_id

      Observation.find_by(id: mo_obs_id)
    end

    # Returns the created link, or nil when validation failed.
    def create_crosslink(mo_obs)
      ExternalLink.create!(
        user: @user, target: mo_obs, external_site: inat_site,
        external_id: @inat_obs[:id].to_s, relationship: :remote_manual
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "InatImport: failed to create remote_manual ExternalLink for " \
        "Observation #{mo_obs.id} (iNat #{@inat_obs[:id]}): #{e.message}"
      )
      nil
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
      return unless builder.unlicensed_obs == 1

      inat_import.add_license_added_obs(inat_id: @inat_obs[:id])
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
