# frozen_string_literal: true

# iNaturalist external-site link for a Name. Uses name s.s. —
# including group gets no hits.
class Tab::Name::Inat < Tab::Name::ExternalBase
  def title
    "iNaturalist"
  end

  def path
    "https://www.inaturalist.org/search?q=#{@name.sensu_stricto}"
  end
end
