# frozen_string_literal: true

# GET link to a download route — delegates to `Components::Link::Download`,
# adding button styling. Defaults to `btn btn-default`.
# Pass `variant:` to override.
#
# @example
#   Button(type: :download,
#     name: :download.ti,
#     target: new_download_species_list_path(id: @sl.id)
#   )
class Components::Button::Download < Components::Link::Download
  def initialize(target: nil, name: nil, icon: :download, variant: nil,
                 **opts)
    tab = opts.delete(:tab)
    super(target: target, tab: tab, name: name, icon: icon,
          button: variant, **opts)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
