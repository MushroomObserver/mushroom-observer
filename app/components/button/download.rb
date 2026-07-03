# frozen_string_literal: true

# GET link to a download route — delegates to `Components::Link::Download`,
# adding button styling. Defaults to `btn btn-default`.
# Pass `variant:` to override.
#
# @example
#   Button(type: :download,
#     name: :DOWNLOAD.t,
#     target: new_download_species_list_path(id: @sl.id)
#   )
class Components::Button::Download < Components::Link::Download
  def initialize(target:, name: nil, icon: :download, variant: nil, **)
    super(target: target, name: name, icon: icon, button: variant, **)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
