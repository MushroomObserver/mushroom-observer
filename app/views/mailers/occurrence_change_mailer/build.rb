# frozen_string_literal: true

module Views::Mailers::OccurrenceChangeMailer
  # Notify observation owner when their observation is added to or
  # removed from an occurrence. Deviates from FieldsOnlyBody: no
  # blank line between fields and handy_links in text mode (just a
  # single newline), so this writes its own view_template.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User
    prop :sender, _Nilable(::User), default: nil
    prop :observation, ::Observation
    prop :action, ::String

    private

    def intro
      :"email_occurrence_#{@action}_intro".l(
        name: @observation.user_unique_format_name(@receiver),
        user: @sender.legal_name
      )
    end

    def fields
      text = "*#{:Time.l}:* #{Time.zone.now.email_time}\n"
      if @sender
        text += "*#{:By.l}:* #{@sender.legal_name} (#{@sender.login})\n"
      end
      text
    end

    def handy_links = :email_handy_links.l

    def links
      [[:email_links_show_object.t(type: :observation),
        "#{MO.http_domain}/#{@observation.id}"],
       *occurrence_link,
       [:email_links_latest_changes.t, MO.http_domain]]
    end

    def occurrence_link
      return [] unless @observation.occurrence_id

      [[:email_links_show_object.t(type: :occurrence),
        "#{MO.http_domain}/occurrences/#{@observation.occurrence_id}"]]
    end
  end

  class Html < Build
    include Views::Mailers::HtmlMode

    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      emit_tp(fields)
      emit_tp(handy_links)
      render_links_section(links)
    end
  end

  class Text < Build
    include Views::Mailers::TextMode

    def view_template
      emit_tp(intro)
      gap
      emit_tp(fields)
      newline
      emit_tp(handy_links)
      gap
      render_links_section(links)
      newline
    end
  end
end
