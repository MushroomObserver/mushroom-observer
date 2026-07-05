# frozen_string_literal: true

module Views::Mailers::UserQuestionMailer
  # User asking user about anything else.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :sender, ::User
    prop :receiver, ::User
    prop :message, ::String

    private

    def intro
      :email_user_question_intro.l(user: @sender.legal_name,
                                   email: @sender.email)
    end

    def handy_links
      :email_can_respond.l(name: @sender.legal_name, email: @sender.email).
        sub(/\n*\z/, "\n#{:email_handy_links.l}")
    end

    def links
      [[:email_links_show_object.t(type: :user),
        "#{MO.http_domain}/users/#{@sender.id}"],
       [:email_links_stop_sending.t,
        "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
        "?type=general_question"],
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
