# Mass-mailing about new features.
class FeaturesEmail < AccountMailer
  def build(user, features)
    setup_user(user)
    @title = :email_subject_features.l
    @features = features
    mo_mail(@title, to: user)
  end
end
