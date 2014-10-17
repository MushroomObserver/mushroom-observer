# Let curators know about a specimen added by a non-curator.
class AddSpecimenEmail < AccountMailer
  def build(sender, receiver, specimen)
    setup_user(receiver)
    @title = :email_subject_add_specimen_not_curator.l(
      herbarium_name: specimen.herbarium.name
    )
    @sender = sender
    @specimen = specimen
    debug_log(:add_specimen_not_curator, sender, receiver, specimen: specimen)
    mo_mail(@title, to: receiver, reply_to: sender)
  end
end
