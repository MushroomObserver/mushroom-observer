# frozen_string_literal: true

#  ==== Obs-show section-update turbo_stream dispatcher
#
#  Used by the five controllers whose CRUD actions write to a
#  sub-panel of the obs-show page (collection_numbers,
#  herbarium_records, sequences, external_links, and naming votes).
#  After a successful create / update / destroy, each controller's
#  `render_<thing>_section_update` private method calls
#  `render_obs_section_update(identifier:, panel:)` to broadcast two
#  turbo_stream actions in one response:
#
#  - `replace` the `#observation_<identifier>` sub-panel container
#    with the supplied Phlex panel view
#  - `update` the `#page_flash` div with the controller's
#    accumulated flash messages so the user sees the success /
#    error notice without a page reload
#
#  Replaces the `observations/show/_section_update.erb` partial
#  that all five controllers used to render.
#
module ApplicationController::SectionUpdater
  private

  # @param identifier [String] the obs-show panel id segment, e.g.
  #   "collection_numbers" → `#observation_collection_numbers` target
  # @param panel [Phlex::SGML] the panel view to render inside the
  #   replaced container (a `Views::Controllers::Observations::Show::*`
  #   class)
  def render_obs_section_update(identifier:, panel:)
    render(turbo_stream: [
             turbo_stream.replace("observation_#{identifier}", panel),
             turbo_stream.update("page_flash") do
               helpers.flash_notices_html
             end
           ])
  end
end
