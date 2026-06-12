# frozen_string_literal: true

# "Create license" link.
class Tab::License::New < Tab::Base
  def title
    :create_license_title.t
  end

  def path
    new_license_path
  end

  def model
    License
  end
end
