# frozen_string_literal: true

#
## iNat iobervation_photo key/values
# {:id=>351481052,
#  :position=>0,
#  :uuid=>"6c223538-04d6-404c-8e84-b7d881dbe550",
#  :photo_id=>377332865,
#  :photo=>
#   {:id=>377332865,
#    :license_code=>"cc-by-nc",
#    :original_dimensions=>{:width=>2048, :height=>1534},
#    :url=>"https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/square.jpeg",
#    :attribution=>"(c) Tim C., some rights reserved (CC BY-NC)",
#    :flags=>[],
#    :moderator_actions=>[],
#    :hidden=>false}}

# some MO image attributes
#  string "content_type", limit: 100
#  integer "user_id"
#  date "when"
#  text "notes"
#  string "copyright_holder", limit: 100
#  integer "license_id", default: 1, null: false
#  integer "width"
#  integer "height"
#  boolean "ok_for_export", default: true, null: false
#  string "original_name", limit: 120, default: ""
#  boolean "gps_stripped", default: false, null: false
#  boolean "diagnostic", default: true, null: false

# Describes one iNat observation photo (derived from an Inat::Obs)
# mapping iNat key/values to MO Image attributes and associations
# Example use:
# Inat::ObsPhoto.new(<imported_inat_obs>.observation_photos.first)
class Inat
  class ObsPhoto
    def initialize(inat_obs_photo_data)
      @photo = inat_obs_photo_data
    end

    def copyright_holder = @photo[:photo][:attribution]

    # https://www.iana.org/assignments/media-types/media-types.xhtml#image
    def content_type = "img/jpeg"

    def license = Inat::License.new(@photo[:photo][:license_code]).mo_license
    delegate :id, to: :license, prefix: true

    # Repurpose MO Image.notes to include some iNat photo data
    # (iNat photos don't have notes or equivalent.)
    def notes
      "Imported from iNat #{DateTime.now.utc.strftime("%Y-%m-%d %H:%M:%S %z")}"
    end

    # iNat doesn't preserve (or maybe reveal) user's original filename
    # so map it to an iNat uuid
    def original_name = "iNat photo uuid #{@photo[:uuid]}"
    def url = @photo[:photo][:url].sub("/square.", "/original.")
  end
end
