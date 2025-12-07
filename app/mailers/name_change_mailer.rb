# frozen_string_literal: true

# Notify user of change in name description.
class NameChangeMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  # Refactored to accept serializable arguments for deliver_later compatibility.
  # ObjectChange instances are constructed here from the IDs and versions.
  def build(**args)
    args => { sender:, receiver:, name:, old_name_ver:, new_name_ver:,
              description:, old_desc_ver:, new_desc_ver:, review_status: }
    setup_user(receiver)
    @name_change = ObjectChange.new(name, old_name_ver, new_name_ver)
    @desc_change = ObjectChange.new(description, old_desc_ver, new_desc_ver)
    @title = :email_subject_name_change.l(name: calc_search_name(@name_change))
    @sender = sender
    @time = name.updated_at
    @review_status = calc_review_status(review_status)
    debug_log(:name_change, sender, receiver,
              name: name, description: description)
    mo_mail(@title, to: receiver)
  end

  private

  def calc_review_status(status)
    :"review_#{status}".l if status != "no_change"
  end

  def calc_search_name(name_change)
    (name_change.old_clone || name_change.new_clone).
      user_real_search_name(@user)
  end
end
