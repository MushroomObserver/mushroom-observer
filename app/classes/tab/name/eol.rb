# frozen_string_literal: true

# Encyclopedia of Life external-site link for a Name.
class Tab::Name::Eol < Tab::Name::ExternalBase
  def title
    "EOL"
  end

  def path
    @name.eol_url
  end
end
