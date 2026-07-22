# frozen_string_literal: true

# "Add publication" link.
class Tab::Publication::New < Tab::Base
  def title
    :add_object.t(type: :publication)
  end

  def path
    new_publication_path
  end
end
