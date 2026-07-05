# frozen_string_literal: true

# Let curators know about a herbarium_record added by a non-curator.
class AddHerbariumRecordMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, herbarium_record:)
    setup_user(receiver)
    subject = :email_subject_add_herbarium_record_not_curator.l(
      herbarium_name: herbarium_record.herbarium.name
    )
    debug_log(:add_herbarium_record_not_curator, sender, receiver,
              herbarium_record:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, sender:,
                                    herbarium_record: })
  end
end
