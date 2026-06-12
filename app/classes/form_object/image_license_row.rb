# frozen_string_literal: true

# A single row in the bulk image-license updater form. Each row
# represents one (copyright_holder, license_id) grouping of the
# user's images — submitting the form updates all images in the
# group at once.
#
# Held inside `FormObject::ImageLicenseUpdates.rows`. Submitted as
# `params[:updates][<index>][<field>]`.
class FormObject::ImageLicenseRow < FormObject::Base
  attribute :license_count, :integer
  attribute :new_holder, :string
  attribute :old_holder, :string
  attribute :new_id, :integer
  attribute :old_id, :integer

  # Per-row available licenses, an array of [label, id] pairs for the
  # select. Display-only — not submitted.
  attr_accessor :licenses

  def initialize(licenses: [], **attrs)
    super(**attrs)
    @licenses = licenses
  end
end
