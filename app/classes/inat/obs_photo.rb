# frozen_string_literal: true

# Describes one iNat observation photo (derived from an Inat::Obs)
# mapping iNat key/values to MO Image attributes and associations
# Example use:
# Inat::ObsPhoto.new(<imported_inat_obs>.observation_photos.first)
class Inat
  class ObsPhoto
    def initialize(inat_obs_photo_data)
      @photo = inat_obs_photo_data
    end

    def copyright_holder
      @photo[:attribution]
    end

    # https://www.iana.org/assignments/media-types/media-types.xhtml#image
    def content_type
      "img/jpeg"
    end

    def license
      Inat::License.new(@photo[:license_code]).mo_license
    end

    delegate :id, to: :license, prefix: true

    # Repurpose MO Image.notes to include some iNat photo data
    # (iNat photos don't have notes or equivalent.)
    def notes
      "Imported from iNat #{DateTime.now.utc.strftime("%Y-%m-%d %H:%M:%S %z")}"
    end

    # iNat doesn't preserve (or maybe reveal) user's original filename
    # so map it to an iNat uuid
    def original_name
      "iNat photo uuid #{@photo[:uuid]}"
    end

    def url
      @photo[:url].sub("/square.", "/original.")
    end
  end
end
