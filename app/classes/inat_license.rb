# frozen_string_literal: true

#  == Instance methods
#
#  mo_license::  Corresponding MO License, if any

# NOTE: both iNat observations and photos have a license_code
# Info re licenses at
# https://github.com/inaturalist/inaturalist/blob/main/app/models/shared/license_module.rb
# https://creativecommons.org/share-your-work/cclicenses/

# Provide information about iNat licenses
class InatLicense
  def initialize(license_code = nil)
    @license_code = license_code
  end

  def mo_license
    return nil unless @license_code

    license =
      License.where(License[:url] =~ cc_subdir(@license_code)).
      where(deprecated: false).
      order(id: :asc).last

    return license if license.present?
    return current_public_domain if @license_code == "cc0"

    nil
  end

  ##### private

  def cc_subdir(license_code)
    "licenses/#{license_code.sub(/^cc-/, "")}/"
  end

  def current_public_domain
    # match old-style "/Public_domain/" or new style "/publicdomain/"
    License.where(License[:url] =~ /public_?domain/i).
      where(deprecated: false).
      order(id: :asc).last
  end
end
