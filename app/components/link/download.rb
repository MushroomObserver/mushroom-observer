# frozen_string_literal: true

# GET link to a download route. Defaults to a download icon and the
# generic "Download" label. Source of truth for download links;
# `Components::Button::Download` delegates here.
#
# @example
#   render(Components::Link::Download.new(
#     name: :download.ti,
#     target: new_download_species_list_path(id: @sl.id)
#   ))
class Components::Link::Download < Components::Link::Get
  def initialize(target: nil, tab: nil, name: nil, icon: :download, **)
    name = name.presence || :download.ti unless tab
    super(target: target, tab: tab, name: name, action: :download,
          icon: icon, **)
  end
end
