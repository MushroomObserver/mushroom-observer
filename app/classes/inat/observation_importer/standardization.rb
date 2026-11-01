# frozen_string_literal: true

class Inat
  class ObservationImporter
    # Per-observation project/field-slip standardization and
    # unlicensed-image recording (#5259).
    module Standardization
      private

      # Photos skipped for a missing iNat license, recorded with who
      # and which license choice so the pattern is reviewable.
      def record_unlicensed_images(builder)
        return unless builder.skipped_images.positive?

        @inat_import.add_unlicensed_image_event(
          inat_id: @inat_obs[:id], login: @inat_obs[:user][:login],
          license_code: @inat_obs[:license_code],
          count: builder.skipped_images
        )
      end

      # Inline standardization against the import's target project. A
      # failure is logged; the observation's import still counts.
      def standardize_for_project
        standardizer.standardize(@observation, inat_id: @inat_obs[:id])
      rescue StandardError => e
        log_with_response_error(
          "Standardization failed for iNat #{@inat_obs[:id]}: #{e.message}"
        )
      end

      def standardizer
        @standardizer ||= Inat::ProjectSlipStandardizer.new(@inat_import)
      end
    end
  end
end
