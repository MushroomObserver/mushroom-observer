# frozen_string_literal: true

module Views::Mailers::AddHerbariumRecordMailer
  # Let curators know about a herbarium_record added by a non-curator.
  # No fields, no boxed message, no report_abuse — just intro +
  # handy_links + links, so this writes its own view_template rather
  # than force-fitting StandardMessageBody or FieldsOnlyBody.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User
    prop :sender, ::User
    prop :herbarium_record, ::HerbariumRecord

    private

    def herbarium = @herbarium_record.herbarium

    def intro
      :email_add_herbarium_record_not_curator_intro.l(
        login: @receiver.login, herbarium_name: herbarium.name,
        herbarium_label: @herbarium_record.herbarium_label
      )
    end

    def handy_links = :email_handy_links.l

    def links
      [[:email_links_show_object.t(type: :herbarium_record),
        herbarium_record_url(host: MO.http_domain, id: @herbarium_record.id)],
       [:email_links_show_object.t(type: :herbarium),
        herbarium_url(host: MO.http_domain, id: herbarium.id)],
       [:email_links_show_user.t(user: @receiver.login),
        user_url(host: MO.http_domain, id: @sender.id)]]
    end
  end

  class Html < Build
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      emit_tp(handy_links)
      render_links_section(links)
    end
  end

  class Text < Build
    def view_template
      emit_tp(intro)
      gap
      emit_tp(handy_links)
      gap
      render_links_section(links)
      newline
    end
  end
end
