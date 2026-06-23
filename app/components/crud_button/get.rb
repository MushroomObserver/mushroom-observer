# frozen_string_literal: true

class Components::CRUDButton
  # GET `CRUDButton` — emits `<a>` (link_to), not a form-wrapped
  # button. Idempotent navigations (edit, download, etc.) use this
  # rather than the form-button branch.
  #
  # The `action:` kwarg controls path-prefixing for model targets
  # via the parent `NAMED_ROUTE_ACTIONS` whitelist (`:edit`, `:new`,
  # `:download` → prefixed paths; everything else → bare path).
  #
  # @example edit link via a model target
  #   render(Components::CRUDButton::Get.new(
  #     target: @herbarium, action: :edit, icon: :edit
  #   ))
  #
  # @example explicit-path download link
  #   render(Components::CRUDButton::Get.new(
  #     name: :DOWNLOAD.t,
  #     target: new_download_species_list_path(id: @sl.id),
  #     action: :download, icon: :download
  #   ))
  class Get < Components::CRUDButton
    def initialize(target:, name:, **args)
      super(target: target, name: name, method: :get, **args)
    end
  end
end
