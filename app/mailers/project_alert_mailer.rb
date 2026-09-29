# frozen_string_literal: true

# One message per project admin per cycle, naming the observations an
# external site has newly identified as something the project watches
# (#5416). A digest rather than a message per identification: a taxon
# swap on iNat landing on a watched name would be surprising, but it is
# the case that would otherwise flood an inbox.
class ProjectAlertMailer < ApplicationMailer
  def build(receiver:, alerts:)
    setup_user(receiver)
    subject = :email_subject_project_alert.l(count: alerts.size)
    debug_log(:project_alert, nil, receiver, count: alerts.size.to_s)
    mo_mail(subject, to: receiver,
                     view_params: { subject: subject, receiver: receiver,
                                    alerts: alerts })
  end
end
