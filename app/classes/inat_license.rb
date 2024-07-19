# frozen_string_literal: true

# class to map iNat APi license_code's to MO license codes
#
#  == Instance methods
#
#  mo_license::  Corresponding MO License, if any

# NOTE: both iNat observations and photos have a license_code
# Info re licenses at
# https://github.com/inaturalist/inaturalist/blob/main/app/models/shared/license_module.rb
# https://creativecommons.org/share-your-work/cclicenses/
#
class InatLicense
  def initialize(license_code = nil)
    @license_code = license_code
  end

  def mo_license
    return License.narrowest_available if unlicensed?
    return current_public_domain if @license_code == "cc0"

    License.where(License[:url] =~ cc_subdir(@license_code)).
      where(deprecated: false).
      order(id: :asc).last
  end

  ##### private

  def cc_subdir(license_code)
    "licenses/#{license_code.sub(/^cc-/, "")}/"
  end

  # iNat API returns "license_code"=>nil, rather than "C" for unlicensed works
  def unlicensed?
    @license_code.nil?
  end

  def current_public_domain
    # match old-style "/Public_domain/" or new style "/publicdomain/"
    License.where(License[:url] =~ /public_?domain/i).
      where(deprecated: false).
      order(id: :asc).last
  end
end
