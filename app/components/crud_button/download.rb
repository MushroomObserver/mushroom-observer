# frozen_string_literal: true

class Components::CRUDButton
  # GET-method `CRUDButton` with the download-action defaults baked
  # in: `action: :download`, `icon: :download`. Path prefixing
  # follows the parent `NAMED_ROUTE_ACTIONS` whitelist.
  #
  # The species-list download is the lone caller today — its route
  # shape doesn't match `download_<resource>_path` (the named route
  # is `new_download_species_list_path`), so the caller passes an
  # explicit String target rather than a model.
  #
  # @example Phlex caller (explicit-path target)
  #   render(Components::CRUDButton::Download.new(
  #     name: :DOWNLOAD.t,
  #     target: new_download_species_list_path(id: @sl.id)
  #   ))
  class Download < Components::CRUDButton::Get
    def initialize(target:, name: nil, **args)
      # `unless args.key?(:icon)` (not `||=`) so callers can opt out of
      # the default icon by passing `icon: nil` explicitly.
      args[:icon] = :download unless args.key?(:icon)
      super(target: target,
            name: name.presence || :DOWNLOAD.t,
            action: :download,
            **args)
    end
  end
end
