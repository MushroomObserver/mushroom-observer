# frozen_string_literal: true

# Renders any pending flash notices as a `Components::Alert`,
# colour-coded by severity (success / warning / danger). Clears the
# notices off the session afterward so subsequent renders don't
# duplicate them.
#
# Rendered into the page from `Views::Layouts::App::PageFlash` and
# into turbo-stream responses from
# `ApplicationController::FlashNotices#flash_notices_html` /
# `#turbo_stream_flash_update`.
module Views::Layouts
  class App::FlashNotices < Views::Base
    # `flash_notices?`, `flash_get_notices`, `flash_notice_level`,
    # `flash_clear` are exposed via `helper_method` on
    # `ApplicationController::FlashNotices`; Phlex needs the explicit
    # registration to call them as plain methods.
    register_value_helper :flash_notices?
    register_value_helper :flash_get_notices
    register_value_helper :flash_notice_level
    register_value_helper :flash_clear

    def view_template
      return unless flash_notices?

      notices = flash_get_notices
      severity = severity_for(flash_notice_level)
      flash_clear

      render(::Components::Alert.new(
               level: severity, id: "flash_notices", class: "mt-3"
             )) { trusted_html(notices) }
    end

    private

    def severity_for(level)
      case level
      when 0 then :success
      when 1 then :warning
      when 2 then :danger
      end
    end
  end
end
