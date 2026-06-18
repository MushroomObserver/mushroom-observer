# frozen_string_literal: true

module Views::Controllers::Support
  # Donation confirmation page — shows the user the donation details
  # they entered and provides a PayPal hand-off button.
  class Confirm < Views::FullPageBase
    prop :donation, ::Donation

    def view_template
      add_page_title(:confirm_title.l)
      trusted_html(:confirm_text.tp)

      p { render_details }
      div(class: "text-center") { render_paypal_form }
    end

    private

    def render_details
      plain("#{:confirm_amount.l}: $#{formatted_amount}")
      br
      yep_or_nope = @donation.recurring ? :YEP.l : :NOPE.l
      plain("#{:confirm_recurring.l}: #{yep_or_nope}")
      br
      render_who_or_anonymous
      br
    end

    def formatted_amount
      number_with_precision(@donation.amount || 0, precision: 2)
    end

    def render_who_or_anonymous
      if @donation.anonymous
        plain(:donate_anonymous.l)
      else
        plain("#{:donate_who.l}: #{@donation.who}")
        br
        plain("#{:donate_email.l}: #{@donation.email}")
      end
    end

    def render_paypal_form
      form(id: "donate_form", name: "_xclick",
           action: "https://www.paypal.com/cgi-bin/webscr",
           method: "post") do
        render_paypal_hidden_fields
        render_paypal_submit_button
      end
    end

    def render_paypal_hidden_fields
      hidden_input("business", MO.donation_business)
      hidden_input("item_name", MO.site_name)
      hidden_input("currency_code", "USD")
      if @donation.recurring
        render_recurring_hidden_fields
      else
        hidden_input("cmd", "_donations")
        hidden_input("amount", @donation.amount)
      end
      hidden_input("cancel_return", "#{MO.http_domain}/support/donate")
      hidden_input("return", "#{MO.http_domain}/support/thanks")
    end

    def render_recurring_hidden_fields
      hidden_input("cmd", "_xclick-subscriptions")
      hidden_input("a3", @donation.amount)
      hidden_input("p3", "1")
      hidden_input("t3", "M")
      hidden_input("src", "1")
      hidden_input("no_note", "1")
    end

    def render_paypal_submit_button
      # Phlex blocks `onclick=` as unsafe. The PayPal flow needs an
      # inline `transferAmount()` handler so the amount input value
      # gets propagated to the form's `amount` hidden field before
      # POST. Wrap the literal markup in a SafeBuffer so
      # `trusted_html` emits it raw.
      trusted_html(::ActiveSupport::SafeBuffer.new(<<~HTML))
        <input type="image"
               src="https://www.paypal.com/en_US/i/btn/btn_donate_LG.gif"
               border="0" name="submit" onclick="transferAmount()"
               alt="Make payments with PayPal - it's fast, free and secure!">
      HTML
    end

    def hidden_input(name, value)
      input(type: "hidden", name: name, value: value.to_s)
    end
  end
end
