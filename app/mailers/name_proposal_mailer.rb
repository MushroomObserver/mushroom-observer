# frozen_string_literal: true

# Notify user of name proposal for their obs.
class NameProposalMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, naming:, observation:)
    setup_user(receiver)
    subject = :email_subject_name_proposal.l(
      name: naming.text_name(receiver), id: observation.id
    )
    debug_log(:name_proposal, sender, receiver, naming:, observation:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, naming:,
                                    observation: })
  end
end
