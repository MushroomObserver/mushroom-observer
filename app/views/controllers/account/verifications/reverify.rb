# frozen_string_literal: true

# Action template for `Account::VerificationsController#reverify` —
# shown when an unverified user (or a logged-in user trying to verify
# someone else) lands on a verification link. Page title plus the
# textile-rendered reverification instructions and a "send another
# verification email" submit.
module Views::Controllers::Account::Verifications
  class Reverify < Views::FullPageBase
    prop :unverified_user, ::User

    def view_template
      add_page_title(:email_welcome.t(user: @unverified_user.legal_name))

      Help(content: help_text)
      Button(
        type: :post,
        name: :reverify_link.t,
        target: account_resend_verification_email_path(
          id: @unverified_user.id
        ),
        variant: :primary, class: "mt-2",
        id: "account_reverify_link"
      )
    end

    private

    def help_text
      capture do
        trusted_html(:reverify_note.tp(user: @unverified_user.login))
        br
        trusted_html(:email_spam_notice.tp)
      end
    end
  end
end
