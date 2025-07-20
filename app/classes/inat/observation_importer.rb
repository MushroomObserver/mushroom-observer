# frozen_string_literal: true

class Inat
  # Imports a parsed page of iNat observations.
  class ObservationImporter
    include Inat::Constants

    delegate :cancel?, to: :@inat_import

    def initialize(inat_import, user)
      @inat_import = inat_import
      @user = user
    end

    # Import a parsed page of iNat observations.
    def import_page(page)
      page["results"].each do |result|
        return false if cancel?

        import_one_result(JSON.generate(result))
      end
    end

    private

    def import_one_result(result)
      @inat_obs = Inat::Obs.new(result)
      return unless @inat_obs.importable?

      builder = Inat::MoObservationBuilder.new(inat_obs: @inat_obs, user: @user)
      @observation = builder.mo_observation

      update_inat_observation
      increment_imported_counts
      update_timings
    end

    def update_inat_observation
      update_mushroom_observer_url_field
      sleep(1)
      update_description
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
    end

    def update_description
      return if super_importer? && importing_someone_elses_obs?

      description = @inat_obs[:description]
      updated_description =
        "#{IMPORTED_BY_MO} #{Time.zone.today.strftime(MO.web_date_format)}"
      updated_description.prepend("#{description}\n\n") if description.present?

      payload = { observation: { description: updated_description,
                                 ignore_photos: 1 } }
      path = "observations/#{@inat_obs[:id]}?ignore_photos=1"
      Inat::APIRequest.new(@inat_import.token).
        request(method: :put, path: path, payload: payload)
    end

    def importing_someone_elses_obs?
      @inat_obs[:user][:login] != @inat_import.inat_username
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

    def super_importer?
      InatImport.super_importers.include?(@user)
    end
  end
end
