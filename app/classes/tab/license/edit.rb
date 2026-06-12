# frozen_string_literal: true

# "Edit license" link.
class Tab::License::Edit < Tab::Base
  def initialize(license:)
    super()
    @license = license
  end

  def title
    :EDIT.t
  end

  def path
    edit_license_path(@license.id)
  end

  def model
    @license
  end
end
