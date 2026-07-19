# frozen_string_literal: true

module Views::Layouts::App
  # Top-of-page callout banners:
  #
  # - **Impersonation / admin mode**: a red "DANGER" strip when the
  #   viewer is in admin mode OR currently viewing as a different
  #   user (via `session[:real_user_id]`).
  # - **Active site banner**: the `Banner.current` message (if any)
  #   wrapped in a dismissible `Components::Alert` with a chevron
  #   show/hide control wired through the `banner` Stimulus
  #   controller.
  class Banners < Views::Base
    register_value_helper :session

    ADMIN_BANNER_CLASSES = "h3 text-center font-weight-bold p-2"

    def view_template
      banner = ::Banner.current
      div(id: "banners", class: "hidden-print") do
        render_admin_banner
        render_site_banner(banner) if banner
      end
    end

    private

    def render_admin_banner
      if in_admin_mode?
        div(id: "admin_banner", class: ADMIN_BANNER_CLASSES) do
          plain("DANGER: You are in administrator mode. " \
                "Proceed with caution.")
        end
      elsif session[:real_user_id].present?
        div(id: "admin_banner", class: ADMIN_BANNER_CLASSES) do
          plain("DANGER: You are currently logged in as #{current_user.login}.")
        end
      end
    end

    def render_site_banner(banner)
      div(data: { controller: "banner" }) do
        Alert(
          level: :success,
          class: "message-banner",
          data: { banner_target: "banner" }
        ) { render_alert_contents(banner) }
        render_show_button_row
      end
    end

    def render_alert_contents(banner)
      Button(
        variant: :strip,
        id: "dismiss-banner",
        class: "close",
        data: { banner_target: "dismissButton",
                version: banner.version },
        aria: { label: :close.ti }
      ) do
        Icon(type: :chevron_up, title: :close.ti)
      end
      p { trusted_html(banner.message.t) }
    end

    def render_show_button_row
      div(class: "position-relative w-100 py-2 text-right",
          data: { banner_target: "container" }) do
        div(class: "show_banner_icon text-green d-block",
            data: { banner_target: "showButton" }) do
          Icon(type: :chevron_down, title: :show.ti)
        end
      end
    end
  end
end
