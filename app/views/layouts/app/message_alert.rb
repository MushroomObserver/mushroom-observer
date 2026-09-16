# frozen_string_literal: true

module Views::Layouts::App
  # A single translated flash message, rendered as trusted HTML. For
  # broadcasting an ad-hoc alert outside the session-based flash queue
  # (e.g. a background job's Turbo Stream update to #page_flash) --
  # see Inat::ObservationResyncer#render_flash. Self-contained (message/
  # level are props) so it can be passed alone to
  # `ApplicationController.renderer.render`; see
  # .claude/rules/phlex_reference.md's "Rendering Phlex outside a
  # request" for why a block can't be passed at that call site instead.
  class MessageAlert < Views::Base
    prop :message, String
    prop :level, _Union(:success, :info, :warning, :danger)

    def view_template
      Alert(level: @level, id: "flash_notices", class: "mt-3") do
        trusted_html(@message)
      end
    end
  end
end
