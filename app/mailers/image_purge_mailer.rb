# frozen_string_literal: true

# Tells a user which of their observations, glossary terms and projects
# lost an image when the photo's holder had their images removed from MO
# (#5521). entries: ImagePurge::Notices::Entry#to_h, one per image.
class ImagePurgeMailer < ApplicationMailer
  def build(receiver:, purge:, entries:)
    setup_user(receiver)
    subject = :email_subject_image_purge.l(count: entries.size)
    debug_log(:image_purge, nil, receiver, count: entries.size.to_s)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, entries:,
                                    holder: holder(purge) })
  end

  private

  def holder(purge)
    if purge.target_user
      purge.target_user.login
    else
      :image_purge_inat_holder.l(login: purge.inat_login)
    end
  end
end
