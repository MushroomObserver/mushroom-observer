# frozen_string_literal: true

module Views::Mailers::AuthorMailer
  # Ask reviewers for authorship credit.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :sender, ::User
    prop :object, _Interface(:type_tag, :parent, :id)
    prop :message, ::String

    private

    def intro
      :email_author_request_intro.l(
        user: @sender.legal_name, email: @sender.email,
        object: @object.parent.unique_format_name
      )
    end

    def handy_links = :email_handy_links.l

    def links
      type = @object.type_tag
      [[:author_request_add_author.t,
        "#{MO.http_domain}/descriptions/authors/#{@object.id}" \
        "?type=#{type}&add=#{@sender.id}"],
       [:email_links_show_user.t, "#{MO.http_domain}/users/#{@sender.id}"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end
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
      render_message_box { trusted_html(@message.tp) }
      emit_tp(handy_links)
      render_links_section(links)
      emit_tp(report_abuse)
    end
  end

  class Text < Build
    include Views::Mailers::CommonSections

    def html? = false

    def view_template
      emit_tp(intro)
      plain("\n\n")
      trusted_html(@message.tp.html_to_ascii)
      plain("\n\n#{"-" * 50}\n\n")
      emit_tp(handy_links)
      plain("\n\n")
      render_links_section(links)
      plain("\n")
      emit_tp(report_abuse)
    end
  end
end
