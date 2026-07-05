# frozen_string_literal: true

module Views::Mailers::NameProposalMailer
  # Notify user of name proposal for their obs.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User
    prop :naming, ::Naming
    prop :observation, ::Observation

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

    def stop_sending_link
      return [] if @receiver.watching?(@observation)

      [[:email_links_stop_sending.t,
        "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
        "?type=observations_naming"]]
    end

    def footer_links
      [[:email_links_change_prefs.t,
        "#{MO.http_domain}/account/preferences/edit"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end

    def show_object_url
      "#{MO.http_domain}/#{@observation.id}"
    end

    def not_interested_url
      "#{MO.http_domain}/interests/set_interest?id=#{@observation.id}" \
        "&type=Observation&user=#{@receiver.id}&state=-1"
    end
  end

  class Html < Build
    include Views::Mailers::CommonSections
    include Views::Mailers::FieldsOnlyBody

    def html? = true
  end

  class Text < Build
    include Views::Mailers::CommonSections
    include Views::Mailers::FieldsOnlyBody

    def html? = false
  end
end
