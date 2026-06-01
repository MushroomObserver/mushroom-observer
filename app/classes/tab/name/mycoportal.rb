# frozen_string_literal: true

# "MyCoPortal" external-site link for a Name. Composed by
# observations name-links panel (via `Tab::Observation::*` once
# that migrates). Mirrors `Tabs::NamesHelper#mycoportal_name_tab`.
class Tab::Name::Mycoportal < Tab::Name::ExternalBase
  def title
    "MyCoPortal"
  end

  def path
    "http://mycoportal.org/portal/taxa/index.php?taxauthid=1&taxon=" \
      "#{@name.sensu_stricto}"
  end
end
