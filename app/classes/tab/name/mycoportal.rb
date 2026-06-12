# frozen_string_literal: true

# "MyCoPortal" external-site link for a Name. Composed by the
# names show page and by observations' web-name-links composer.
class Tab::Name::Mycoportal < Tab::Name::ExternalBase
  def title
    "MyCoPortal"
  end

  def path
    "http://mycoportal.org/portal/taxa/index.php?taxauthid=1&taxon=" \
      "#{@name.sensu_stricto}"
  end
end
