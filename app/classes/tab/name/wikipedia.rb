# frozen_string_literal: true

# Wikipedia external-site link for a Name. Uses name s.s. —
# including "group" matches hits that don't include the name s.s.
class Tab::Name::Wikipedia < Tab::Name::ExternalBase
  def title
    "Wikipedia"
  end

  def path
    "https://en.wikipedia.org/w/index.php?search=#{@name.sensu_stricto}"
  end
end
