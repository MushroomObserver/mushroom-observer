# frozen_string_literal: true

# Map iNat license_code to MO license
# both iNat observations and photos have a license_code
class InatLicense
  def initialize(license_code)
    @license_code = license_code
  end

  def license
    mo_license(@license_code)
  end

  ######### private

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
  def mo_license(license_code)
    # https://creativecommons.org/share-your-work/cclicenses/
    case license_code
    when "C" # all right reserved
      nil # MO has not equivalent
    # FIXME: Either Update MO licenses to include cc-by-nc or
    #  require a waiver whn importing iNat observations
    #  Ditto for other iNat licenses where MO lacks that exact license.
    # Map all iNat NC licenses to MO's newest CC non-commercial license
    when /cc-by-nc/
      License.where(License[:form_name] =~ "ccbyncsa").where(deprecated: false).
        order(id: :asc).last
    # Other iNat "by" licenses => MO's newest CC general share-alike license
    when /cc-by/
      License.where(License[:form_name] =~ "ccbysa").where(deprecated: false).
        order(id: :asc).last
    when "CC0", "PD" # public domain
      # MO's most recent CC public domain
      License.where(License[:form_name] =~ "publicdomain").
        where(deprecated: false).order(id: :asc).last
    else # rubocop:disable Lint/DuplicateBranch
      # map everything else to MO's most restrictive license
      License.where(License[:form_name] =~ "ccbyncsa").where(deprecated: false).
        order(id: :asc).last
    end
  end
end
