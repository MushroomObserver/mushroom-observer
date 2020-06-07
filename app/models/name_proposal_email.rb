# frozen_string_literal: true

# Notify user of name proposal for their obs.
class NameProposalEmail < AccountMailer
  def build(sender, receiver, naming, observation)
    setup_user(receiver)
    @title = :email_subject_name_proposal.l(name: naming.text_name,
                                            id: observation.id)
    @naming = naming
    @observation = observation
    debug_log(:name_proposal, sender, receiver,
              naming: naming, observation: observation)
    mo_mail(@title, to: receiver)
  end
end
