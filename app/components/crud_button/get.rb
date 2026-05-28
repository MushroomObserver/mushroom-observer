# frozen_string_literal: true

class Components::CrudButton
  # GET `CrudButton` — emits `<a>` (link_to), not a form-wrapped
  # button. Idempotent navigations (edit, download, etc.) use this
  # rather than the form-button branch. Used as the Phlex-side
  # equivalent of `LinkHelper#edit_button` and `download_button`
  # (which delegate here).
  #
  # The `action:` kwarg controls path-prefixing for model targets
  # via the parent `NAMED_ROUTE_ACTIONS` whitelist (`:edit`, `:new`,
  # `:download` → prefixed paths; everything else → bare path).
  #
  # @example edit link via a model target
  #   render(Components::CrudButton::Get.new(
  #     target: @herbarium, action: :edit, icon: :edit
  #   ))
  #
  # @example explicit-path download link
  #   render(Components::CrudButton::Get.new(
  #     name: :DOWNLOAD.t,
  #     target: new_download_species_list_path(id: @sl.id),
  #     action: :download, icon: :download
  #   ))
  class Get < Components::CrudButton
    def initialize(target:, name:, **args)
      super(target: target, name: name, method: :get, **args)
    end
  end
end
