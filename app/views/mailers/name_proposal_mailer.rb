# frozen_string_literal: true

# Notify user of name proposal for their obs.
class Views::Mailers::NameProposalMailer < Views::Mailers::Base
  include Views::Mailers::ObservationLinks

  prop :subject, ::String
  prop :receiver, ::User
  prop :naming, ::Naming
  prop :observation, ::Observation

  class Html < self
    include Views::Mailers::FieldsOnlyBody
  end

  class Text < self
    include Views::Mailers::FieldsOnlyBody
  end

  private

  def intro = :email_name_proposal_intro.l(id: @observation.id)

  def fields
    text = "*#{:Name.l}:* #{@naming.user_format_name(@receiver)}\n"
    text += "*#{:Time.l}:* #{@naming.created_at.email_time}\n"
    if @naming.user
      text += "*#{:By.l}:* #{@naming.user.legal_name} " \
              "(#{@naming.user.login})\n"
    end
    @naming.reasons_array.each { |reason| text += reason_field(reason) }
    text
  end

  def reason_field(reason)
    return "" unless reason.used?
    return "*#{reason.label.l}*\n" if reason.notes.blank?

    "*#{reason.label.l}:* #{reason.notes}\n"
  end

  def handy_links = :email_handy_links.l

  def links
    [*subject_links, *stop_sending_link, *footer_links]
  end

  def subject_links
    [[:email_links_show_object.t(type: :observation), show_object_url],
     [:email_links_not_interested.t(type: :observation), not_interested_url]]
  end

  def stop_sending_type = "observations_naming"

  def footer_links
    [[:email_links_change_prefs.t,
      "#{MO.http_domain}/account/preferences/edit"],
     [:email_links_latest_changes.t, MO.http_domain]]
  end
end
