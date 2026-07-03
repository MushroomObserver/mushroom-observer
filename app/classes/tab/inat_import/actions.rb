# frozen_string_literal: true

# Context-nav "Actions" menu for the iNat-import index and show pages.
# Always offers a link to start a new import; the show page also links
# back to the index, while the index page omits the self-link.
class Tab::InatImport::Actions < Tab::Collection
  def initialize(include_index: true)
    super()
    @include_index = include_index
  end

  private

  def tabs
    [
      Tab::InatImport::New.new,
      (Tab::InatImport::Index.new if @include_index)
    ].compact
  end
end
