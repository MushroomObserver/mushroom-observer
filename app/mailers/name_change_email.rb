# Notify user of change in name description.
class NameChangeEmail < AccountMailer
  def build(email)
    @name_change = email.name_change
    @desc_change = email.desc_change
    setup_user(email.to_user)
    @title = :email_subject_name_change.l(name: calc_search_name(@name_change))
    @sender = email.user
    @time = email.queued
    @review_status = calc_review_status(email.review_status)
    debug_log(:name_change, @sender, @user,
              name: @name_change.object, description: @desc_change.object)
    mo_mail(@title, to: @user)
  end

  private

  def calc_review_status(status)
    "review_#{status}".to_sym.l if status != :no_change
  end

  def calc_search_name(name_change)
    (name_change.old_clone || name_change.new_clone).real_search_name
  end
end
