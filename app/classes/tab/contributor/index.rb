# frozen_string_literal: true

# "Site contributors" page link.
class Tab::Contributor::Index < Tab::Base
  def title
    :app_contributors.t
  end

  def path
    contributors_path
  end
end
