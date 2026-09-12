# frozen_string_literal: true

# User wants two Locations/Herbariums/Names merged. Split out of the
# generic WebmasterMailer (#4901) so the Location/Herbarium/Name
# type-dispatch that used to live on those models' own `merge_info`
# methods can move into this mailer's Phlex view instead, without
# dragging that dispatch into WebmasterMailer -- which stays a plain
# "send this text to the webmaster" pipe shared by two other
# controllers that have nothing to do with merging.
class MergeRequestMailer < ApplicationMailer
  after_action :webmaster_delivery, only: [:build]

  # `build`'s body (this whole method, including the Phlex view
  # render inside mo_mail) only actually executes when the
  # `deliver_later` job runs, not synchronously in the controller --
  # so setting the locale here, rather than relying on the
  # controller's request-time locale, is what actually governs the
  # `.ti`/`.l` resolution the view does.
  def build(sender_email:, old_obj:, new_obj:, user:, notes:)
    I18n.locale = MO.default_locale
    mo_mail("#{old_obj.class.name} Merge Request",
            to: MO.webmaster_email_address,
            from: MO.webmaster_email_address,
            reply_to: sender_email,
            content_style: "plain",
            view_params: { old_obj:, new_obj:, user:, notes: })
  end
end
