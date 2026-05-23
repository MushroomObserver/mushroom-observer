# frozen_string_literal: true

# Form object for the bulk image-license updater
# (`Images::LicensesController#edit/update`). The form groups all of
# a user's images by current (copyright_holder, license_id) and lets
# them update each group in one batch. Submitted as
# `params[:updates]` — a hash keyed by row index, each row holding
# new/old copyright_holder and new/old license_id.
#
# Transforms the controller's raw `@data` array of string-keyed
# hashes (from a SQL grouping query) into a typed list of
# `FormObject::ImageLicenseRow` objects so the form component can
# read attributes by name rather than by hash key.
class FormObject::ImageLicenseUpdates < FormObject::Base
  attr_accessor :rows

  def initialize(data: [])
    super()
    @rows = data.map { |datum| build_row(datum) }
  end

  # Override the demodulized class-name default
  # ("ImageLicenseUpdates" → "image_license_updates") so Superform's
  # form scope matches the existing `params[:updates]` wire shape the
  # controller reads. Changing the controller side would be the
  # bigger refactor of the two, so we preserve the wire shape here.
  def self.model_name
    ActiveModel::Name.new(self, nil, "Updates")
  end

  # Force Superform's PATCH form-method (rather than POST) since
  # the form action is the existing license-updater PUT/PATCH route.
  def persisted?
    true
  end

  # Superform's `namespace(key)` resolves a sub-object via
  # `parent_object.send(key)`. We expose each row by its index-
  # string method so `namespace("0")` finds `rows[0]`, letting
  # field renderers inside auto-read row attribute values.
  def respond_to_missing?(name, include_private = false)
    name.to_s.match?(/\A\d+\z/) || super
  end

  def method_missing(name, *args, &block)
    return @rows[name.to_s.to_i] if name.to_s.match?(/\A\d+\z/)

    super
  end

  private

  def build_row(datum)
    holder = datum["copyright_holder"].to_s
    license_id = datum["license_id"].to_i
    FormObject::ImageLicenseRow.new(
      license_count: datum["license_count"].to_i,
      new_holder: holder, old_holder: holder,
      new_id: license_id, old_id: license_id,
      licenses: datum["licenses"]
    )
  end
end
