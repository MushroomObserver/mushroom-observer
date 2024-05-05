# frozen_string_literal: true

# Encapsulates one iNat observation photo (dervied from an ImportedInatObs)
# mapping iNat key/values to MO Image attributes and associations
class InatObsPhoto
  def initialize(inat_obs_photo_data)
    # TODO: Can I get rid of eval?
    # Issue: inat_obs_photo_data is extracted from string which was JSONized
    # Can I do something clever to initialize it with id &/or position?
    # Maybe subclass of imported_inat_obs?
    @inat_obs_photo = eval(inat_obs_photo_data)
  end

  def copyright_holder
    photo[:attribution]
  end

  def license_id
    license(photo).id
  end

  # iNat doesn't preserve (or maybe reveal) user's original filename
  # so map it to an iNat uuid
  def original_name
    "iNat photo uuid #{@inat_obs_photo[:uuid]}"
  end

  # iNat photos don't have notes
  # It's a handy place to put the original photo dimensions
  def notes
    "original dimensions: #{original_width} x #{original_height}"
  end

  ##########

  private

  def photo
    @inat_obs_photo[:photo]
  end

  # iNat Licenses as of 2024-05-05
  # https://github.com/inaturalist/inaturalist/blob/main/app/models/shared/license_module.rb
  #   0 => {code: "C",
  #     name: "Copyright",
  #     url: "http://en.wikipedia.org/wiki/Copyright"},
  #   1 => {code: Observation::CC_BY_NC_SA,
  #     name: "Creative Commons Attribution-NonCommercial-ShareAlike License",
  #     url: "http://creativecommons.org/licenses/by-nc-sa/#{CC_VERSION}/"},
  #   2 => {code: Observation::CC_BY_NC,
  #     name: "Creative Commons Attribution-NonCommercial License",
  #     url: "http://creativecommons.org/licenses/by-nc/#{CC_VERSION}/"},
  #   3 => {code: Observation::CC_BY_NC_ND,
  #     name: "Creative Commons Attribution-NonCommercial-NoDerivs License",
  #     url: "http://creativecommons.org/licenses/by-nc-nd/#{CC_VERSION}/"},
  #   4 => {code: Observation::CC_BY,
  #     name: "Creative Commons Attribution License",
  #     url: "http://creativecommons.org/licenses/by/#{CC_VERSION}/"},
  #   5 => {code: Observation::CC_BY_SA,
  #     name: "Creative Commons Attribution-ShareAlike License",
  #     url: "http://creativecommons.org/licenses/by-sa/#{CC_VERSION}/"},
  #   6 => {code: Observation::CC_BY_ND,
  #     name: "Creative Commons Attribution-NoDerivs License",
  #     url: "http://creativecommons.org/licenses/by-nd/#{CC_VERSION}/"},
  #   7 => {code: "PD",
  #     name: "Public domain",
  #     url: "http://en.wikipedia.org/wiki/Public_domain"},
  #   8 => {code: "GFDL",
  #     name: "GNU Free Documentation License",
  #     url: "http://www.gnu.org/copyleft/fdl.html"},
  #   9 => {code: Observation::CC0,
  #     name: "Creative Commons CC0 Universal Public Domain Dedication",
  #     url: "http://creativecommons.org/publicdomain/zero/#{CC0_VERSION}/"}

  # MO Licenses as of 2024-05-05
  # id: 1,
  #   display_name: "Creative Commons Non-commercial v2.5",
  #   url: "http://creativecommons.org/licenses/by-nc-sa/2.5/",
  #   deprecated: true,
  #   form_name: "ccbyncsa25",
  # id: 2,
  #   display_name: "Creative Commons Non-commercial v3.0",
  #   url: "http://creativecommons.org/licenses/by-nc-sa/3.0/",
  #   deprecated: false,
  #   form_name: "ccbyncsa30",
  # id: 3,
  #   display_name: "Creative Commons Wikipedia Compatible v3.0",
  #   url: "http://creativecommons.org/licenses/by-sa/3.0/",
  #   deprecated: false,
  #   form_name: "ccbysa30",
  # id: 4,
  #   display_name: "Public Domain",
  #   url: "http://creativecommons.org/licenses/publicdomain/",
  #   deprecated: false,
  #   form_name: "publicdomain",

  def license(photo)
    # https://creativecommons.org/share-your-work/cclicenses/
    case photo[:license_code]
    when "cc-by-nc"
      # MO's most recent CC non-commercial license
      License.where(License[:form_name] =~ "ccbync").where(deprecated: false).
        order(id: :asc).last
    when "cc-by-sa"
      # MO's most recent CC share-alike
      License.where(License[:form_name] =~ "ccbysa").where(deprecated: false).
        order(id: :asc).last
    when "pd"
      # MO's most recent CC public domain
      License.where(License[:form_name] =~ "publicdomain").
        where(deprecated: false).order(id: :asc).last
    end
  end

  def original_height
    photo[:original_dimensions][:height]
  end

  def original_width
    photo[:original_dimensions][:width]
  end
end
