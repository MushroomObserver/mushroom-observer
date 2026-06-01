# frozen_string_literal: true

# "All names" link surfaced on the names index page when the
# current query is filtered to `has_observations`. Lets the user
# unfilter by going to the full names index.
class Tab::Name::All < Tab::Base
  def title
    :all_objects.t(type: :name)
  end

  def path
    names_path
  end
end
