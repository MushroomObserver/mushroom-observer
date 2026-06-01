# frozen_string_literal: true

# Base class for external-site links for a Name (MyCoPortal, GBIF,
# EOL, etc.). Carries the shared `target=_blank` / `rel=noopener`
# attrs and model = the Name. Subclasses implement `#title` and
# `#path` (the external URL). `#alt_title` is optional.
class Tab::Name::ExternalBase < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def html_options
    { target: :_blank, rel: :noopener }
  end

  def model
    @name
  end
end
