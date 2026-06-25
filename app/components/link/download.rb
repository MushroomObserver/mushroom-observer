# frozen_string_literal: true

# GET link to a download route. Defaults to a download icon and the
# generic "Download" label. Source of truth for download links;
# `Components::Button::Download` delegates here.
#
# @example
#   render(Components::Link::Download.new(
#     name: :DOWNLOAD.t,
#     target: new_download_species_list_path(id: @sl.id)
#   ))
class Components::Link::Download < Components::Link::Get
  def initialize(target:, name: nil, icon: :download, **)
    super(target: target,
          name: name.presence || :DOWNLOAD.t,
          action: :download,
          icon: icon,
          **)
  end
end
