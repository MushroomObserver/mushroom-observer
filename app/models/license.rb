# frozen_string_literal: true

#
#  = License Model
#
#  Very simple model to hold info about a copyright license.  Originally
#  intended for use by Image, but now extended to Name Descriptions.
#
#  == Deprecation
#
#  Instead of deleting out-dated License's, since that would involve finding
#  and updating thousands of records, we just "deprecate" them instead.  This
#  has the effect of removing it from pulldown menus in the HTML forms.
#
#  == Attributes
#
#  id::           Locally unique numerical id, starting at 1.
#  updated_at::   Date/time it was last updated.
#  deprecated::   Has this been deprecated?
#  display_name:: Name, ex: "Creative Commons Non-commercial v2.5"
#  code::         Code, ex: "ccbyncsa25"
#  url::          URL,  ex: "http://creativecommons.org/licenses/by-nc-sa/2.5/"
#
#  == Class methods
#
#  current_names_and_ids::  List non-deprecated License names/ids.
#
#  == Instance methods
#
#  images::                 Array of Image's that use this License.
#  users::                  Array of User's for whom this is the default License
#  location_descriptions::  Array of Name's that use this License.
#  name_descriptions::      Array of Name's that use this License.
#  text_name::              Alias for +display_name+ for debugging.
#  in_use?::                Is license used by any object?
#  attribute_duplicated?    duplicate display_name, code_, or url
#                           of another License?
#  badge_url::              url of the License badge
#
#  == Callbacks
#
#  None.
#
################################################################################

class License < AbstractModel
  has_many :images
  has_many :location_descriptions
  has_many :name_descriptions
  has_many :users

  validates :display_name, :url, presence: true
  # Don't add indexes because there are few Licenses, and they rarely change
  validates :display_name, :url, uniqueness: true # rubocop:disable Rails/UniqueValidationWithoutIndex
  before_destroy :prevent_destruction_of_license_in_use

  # Use this license if all else equal.
  def self.preferred
    License.find_by(url: "https://creativecommons.org/licenses/by-nc-sa/3.0/")
  end

  # Various debugging things require all models respond to text_name
  def text_name
    display_name.to_s
  end

  # Get list of non-deprecated License's.  Returns an Array of pairs (such as
  # would be needed by a pulldown menu helper):
  #
  #   for name, id in License.current_names_and_ids
  #     puts "license ##{id}: '#{name}'"
  #   end
  #
  def self.current_names_and_ids(current_license = nil)
    result = License.where(deprecated: 0).map { |l| [l.display_name, l.id] }
    if current_license&.deprecated
      result.push([current_license.display_name, current_license.id])
    end
    result
  end

  def copyright_text(year, name)
    # match old style `public_domain` or new style `publicdomain`
    if url.match?(/public_?domain/)
      "".html_safe + :image_show_public_domain.t + " " + name
    else
      "".html_safe + :image_show_copyright.t.to_s + " &copy;".html_safe +
        " #{year} " + name
    end
  end

  def in_use?
    images.any? || users.any? ||
      location_descriptions.any? || name_descriptions.any?
  end

  def attribute_duplicated?
    License.where.not(id: id).and(
      License.where(display_name: display_name).or(
        License.where(url: url)
      )
    ).any?
  end

  LICENSE_URL_WITH_SUBDIR = %r{https?://creativecommons.org/licenses/}
  BADGE_URL_WITH_SUBDIR = "https://licensebuttons.net/l/"

  def badge_url
    "#{url.sub(LICENSE_URL_WITH_SUBDIR, BADGE_URL_WITH_SUBDIR)}88x31.png"
  end

  ###########

  private

  def prevent_destruction_of_license_in_use
    return unless in_use?

    errors.add(:base, "Cannot delete License that's in use")
    throw(:abort)
  end
end
