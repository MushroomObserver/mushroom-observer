# frozen_string_literal: true

# Notify reviewers that a draft has been published.
class PublishNameMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(publisher, receiver, name)
    setup_user(receiver)
    @name = name
    @title = :email_subject_publish_name.l
    @publisher = publisher
    @name = name
    debug_log(:publish_name, publisher, receiver, name: name)
    mo_mail(@title, to: receiver)
  end
end
