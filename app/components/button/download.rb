# frozen_string_literal: true

# GET button with download-action defaults: `action: :download`,
# `icon: :download`. Pass `icon: nil` to opt out of the icon.
#
# The species-list download passes an explicit String target because
# its route doesn't match `download_<resource>_path`.
#
# @example
#   render(Components::Button::Download.new(
#     name: :DOWNLOAD.t,
#     target: new_download_species_list_path(id: @sl.id)
#   ))
class Components::Button::Download < Components::Button::Get
  def initialize(target:, name: nil, icon: :download, **)
    super(target: target,
          name: name.presence || :DOWNLOAD.t,
          action: :download,
          icon: icon,
          **)
  end
end
