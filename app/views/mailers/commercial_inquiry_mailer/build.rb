# frozen_string_literal: true

module Views::Mailers::CommercialInquiryMailer
  # User asking user about an image.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :sender, ::User
    prop :receiver, ::User
    prop :image, ::Image
    prop :message, ::String

    private

    def intro
      :email_commercial_intro.l(user: @sender.legal_name,
                                email: @sender.email,
                                image: @image.unique_text_name)
    end

    def handy_links
      :email_can_respond.l(name: @sender.legal_name, email: @sender.email).
        sub(/\n*\z/, "\n#{:email_handy_links.l}")
    end

    def links
      [[:email_links_show_object.t(type: :image),
        "#{MO.http_domain}/images/#{@image.id}"],
       [:email_links_stop_sending.t,
        "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
        "?type=general_commercial"],
       [:email_links_change_prefs.t,
        "#{MO.http_domain}/account/preferences/edit"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end
  end

  class Html < Build
    include Views::Mailers::StandardMessageBody
  end

  class Text < Build
    include Views::Mailers::StandardMessageBody
  end
end
