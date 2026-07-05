# frozen_string_literal: true

module Views::Mailers::NamingObserverMailer
  # Tell observer someone is interested in their obs. Deviates from
  # the StandardMessageBody shape (an extra warning_msg section
  # between links and report_abuse), so this writes its own
  # view_template rather than including that module.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User # the observer
    prop :naming, ::Naming
    prop :name_tracker, ::NameTracker

    private

    def sender = @name_tracker.user

    def observation = @naming.observation

    def intro
      :email_naming_for_observer_intro.l(
        user: sender.legal_name, email: sender.email, type: :observation,
        name: observation.user_unique_format_name(@receiver)
      )
    end

    def message
      @name_tracker.calc_note(user: @receiver, naming: @naming)
    end

    def handy_links
      :email_can_respond.l(name: sender.legal_name, email: sender.email).
        sub(/\n*\z/, "\n#{:email_handy_links.l}")
    end

    def links
      [[:email_links_show_object.t(type: :observation),
        "#{MO.http_domain}/#{observation.id}"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end

    def warning_msg = :email_naming_for_observation_warning.l
  end

  class Html < Build
    include Views::Mailers::CommonSections

    def html? = true

    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      render_message_box { trusted_html(message.tp) }
      emit_tp(handy_links)
      render_links_section(links)
      emit_tp(warning_msg)
      emit_tp(report_abuse)
    end
  end

  class Text < Build
    include Views::Mailers::CommonSections

    def html? = false

    def view_template
      emit_tp(intro)
      plain("\n\n")
      render_quoted_message
      emit_tp(handy_links)
      plain("\n\n")
      render_links_section(links)
      plain("\n")
      emit_tp(warning_msg)
      plain("\n\n")
      emit_tp(report_abuse)
    end

    private

    def render_quoted_message
      trusted_html(message.tp.html_to_ascii)
      plain("\n\n#{"-" * 50}\n\n")
    end
  end
end
