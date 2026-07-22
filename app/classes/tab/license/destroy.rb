# frozen_string_literal: true

# "Destroy license" button-tab. Only shown on the license show page
# when the license isn't in use. Caller is responsible for the
# `license.in_use?` check.
class Tab::License::Destroy < Tab::Base
  def initialize(license:)
    super()
    @license = license
  end

  def title
    :destroy.ti
  end

  def path
    @license
  end

  def html_options
    { button: :destroy }
  end

  def model
    @license
  end
end
