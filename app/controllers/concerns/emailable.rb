# frozen_string_literal: true

#
#  = Emailable Concern
#
#  This is a module that is included by some controllers that deal with
#  emails.  (Just Observations::EmailsController right now.)
#
#
#  == Helpers
#  can_email_user_question?::           Check if the user or object owner
#                                       accepts emails.
#  temporarily_set_locale?::            Temporarily set a locale for emailing.
#
################################################################################

module Emailable
  extend ActiveSupport::Concern

  included do
    ############################################################################
    #
    #  :Helpers
    #
    ############################################################################

    def can_email_user_question?(target, method: :email_general_question)
      user = target.is_a?(User) ? target : target.user
      return true if user.send(method) && !user.no_emails

      flash_error(:permission_denied.t)
      # Method could also respond to a js handler that flashes directly on page
      redirect_with_query(controller: target.show_controller,
                          action: target.show_action, id: target.id)
      false
    end

    def temporarily_set_locale(locale)
      old_locale = I18n.locale
      # Setting I18n.locale used to incur a significant performance penalty,
      # avoid doing so if not required.  Not sure if this is still the case.
      I18n.locale = locale if I18n.locale != locale
      yield
    ensure
      I18n.locale = old_locale if I18n.locale != old_locale
    end
  end
end
