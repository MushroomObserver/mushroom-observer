# Let curators know about a herbarium_record added by a non-curator.
class AddHerbariumRecordEmail < AccountMailer
  def build(sender, receiver, herbarium_record)
    setup_user(receiver)
    @title = :email_subject_add_herbarium_record_not_curator.l(
      herbarium_name: herbarium_record.herbarium.name
    )
    @sender = sender
    @herbarium_record = herbarium_record
    debug_log(:add_herbarium_record_not_curator, sender, receiver,
              herbarium_record: herbarium_record)
    mo_mail(@title, to: receiver)
  end
end
