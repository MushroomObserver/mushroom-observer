# frozen_string_literal: true

# Ascomycete.org external-site link for a Name. ORs the words
# (no quotes) since the site is Euro-centric and omits many North
# American species — broader matching surfaces more results.
class Tab::Name::AscomyceteOrg < Tab::Name::ExternalBase
  def title
    "Ascomycete.org"
  end

  def path
    "https://ascomycete.org/Search-Results?search=#{@name.sensu_stricto}"
  end
end
