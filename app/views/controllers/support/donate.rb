# frozen_string_literal: true

module Views::Controllers::Support
  # Donation form page — intro/outro textile copy wrapping
  # `Support::Form`.
  class Donate < Views::Base
    prop :donation, ::Donation

    def view_template
      add_page_title(:donate_title.l)
      add_context_nav(::Tab::Support::DonateActions.new(
                        admin: in_admin_mode?
                      ))

      trusted_html(:donate_thanks.tp)
      trusted_html(:donate_explanation.tp)
      render(Form.new(
               @donation,
               action: url_for(controller: "/support", action: :confirm)
             ))
      trusted_html(:donate_snail_mail.tp)
      trusted_html(:donate_fine_print.tp)
    end
  end
end
