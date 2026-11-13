# frozen_string_literal: true

# "Licenses index" link.
class Tab::License::Index < Tab::Base
  def title
    :index_object.t(type: :license)
  end

  def path
    licenses_path
  end

  def model
    License
  end
end
