# frozen_string_literal: true

# Base class for external-site links for a Name (MyCoPortal, GBIF,
# EOL, etc.). Carries the shared `target=_blank` / `rel=noopener`
# attrs and model = the Name. Subclasses implement `#title` and
# `#path` (the external URL). `#alt_title` is optional.
#
# `name:` is optional so this class also covers the search-page
# externals (Index Fungorum search, MycoBank basic search) that
# don't have a per-Name URL — when `name` is nil, `model` returns
# nil and the auto-derived selector class is a plain title-derived
# `<…>_link` (no model flavour).
class Tab::Name::ExternalBase < Tab::Base
  def initialize(name: nil)
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
