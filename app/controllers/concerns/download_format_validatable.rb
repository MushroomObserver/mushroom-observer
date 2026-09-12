# frozen_string_literal: true

#
#  = DownloadFormatValidatable Concern
#
#  Shared format/encoding validation for controllers that read a
#  download format/encoding straight from raw params
#  (Observations::DownloadsController, SpeciesLists::DownloadsController).
#  Single source of truth so the two controllers' valid-value sets
#  can't drift apart.
#
#  == Helpers
#  valid_download_format::    Validate a format param, falling back
#                              to a default.
#  valid_download_encoding::  Validate an encoding param, falling
#                              back to a default.
#
################################################################################

module DownloadFormatValidatable
  extend ActiveSupport::Concern

  included do
    private

    def download_formats
      %w[raw adolf dwca symbiota fundis mycoportal mycoportal_image_list].
        freeze
    end

    def download_encodings
      %w[ASCII WINDOWS-1252 UTF-8 UTF-16].freeze
    end

    def valid_download_format(value, default: "raw")
      download_formats.include?(value) ? value : default
    end

    def valid_download_encoding(value, default: "UTF-8")
      download_encodings.include?(value) ? value : default
    end
  end
end
