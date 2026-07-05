# frozen_string_literal: true

module Views::Mailers::CommentMailer
  # Notify a user of a comment on their object. Reference conversion
  # for issue #4676 — the "full pattern" every later mailer
  # conversion should copy: intro + fields + boxed quoted comment +
  # handy_links + links list + report-abuse footer.
  class Build < Views::Mailers::Base
    # Not `title:` — Literal::Properties would define a `title`
    # reader that shadows Phlex::HTML's own `title` tag-emitting
    # method, breaking `<title>` inside `Html#view_template`.
    prop :subject, ::String # same string CommentMailer used for the
    # mail Subject header, reused verbatim for <title> below.
    prop :receiver, ::User
    prop :sender, ::User
    prop :target, _Interface(:type_tag, :show_controller, :unique_format_name)
    prop :comment, ::Comment
    # "owner" / "response" / "all" — which of the three notification
    # reasons applies to this receiver. Computed by CommentMailer#build
    # (needs an extra Comment query beyond "is this the object's
    # owner?"), not here — views shouldn't be querying the database.
    prop :email_type, ::String

    INTRO_KEYS = {
      "owner" => :email_comment_intro_to_owner,
      "response" => :email_comment_intro_response,
      "all" => :email_comment_intro_other
    }.freeze

    private

    def intro
      INTRO_KEYS.fetch(@email_type).l(
        type: @target.type_tag, name: @target.unique_format_name
      )
    end

    def fields
      text = "*#{:Created.l}:* #{@comment.created_at.email_time}\n"
      if @comment.user
        text += "*#{:By.l}:* #{@comment.user.legal_name} " \
                "(#{@comment.user.login})\n"
      end
      text += "*#{:Summary.l}:* #{@comment.summary}\n"
      text += "*#{:Comment.l}:*\n" if @comment.comment
      text
    end

    def handy_links
      text = "*#{:email_no_respond.l}* #{:email_respond_via_comment.l}"
      text.sub(/\n*\z/, "\n#{:email_handy_links.l}")
    end

    def links
      [*subject_links, *stop_sending_link, *footer_links]
    end

    def subject_links
      type = @target.type_tag
      [[:email_links_show_object.t(type:), show_object_url],
       [:email_links_post_comment.t, post_comment_url],
       [:email_links_not_interested.t(type:), not_interested_url]]
    end

    def stop_sending_link
      return [] if @receiver.watching?(@target)

      [[:email_links_stop_sending.t,
        "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
        "?type=comments_#{@email_type}"]]
    end

    def footer_links
      [[:email_links_change_prefs.t,
        "#{MO.http_domain}/account/preferences/edit"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end

    def show_object_url
      "#{MO.http_domain}#{@target.show_controller}/#{@target.id}"
    end

    def post_comment_url
      "#{MO.http_domain}/comments/new?target=#{@comment.target_id}" \
        "&type=#{@comment.target_type}"
    end

    def not_interested_url
      "#{MO.http_domain}/interests/set_interest?id=#{@comment.target_id}" \
        "&type=#{@comment.target_type}&user=#{@receiver.id}&state=-1"
    end
  end

  class Html < Build
    include Views::Mailers::CommonSections

    def html? = true

    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) { render_body }
    end

    private

    def render_body
      emit_tp(intro)
      emit_tp(fields)
      render_quoted_comment
      emit_tp(handy_links)
      render_links_section(links)
      emit_tp(report_abuse)
    end

    def render_quoted_comment
      return unless @comment.comment

      render_message_box { trusted_html(@comment.comment.tp) }
    end
  end

  class Text < Build
    include Views::Mailers::CommonSections

    def html? = false

    def view_template
      emit_tp(intro)
      plain("\n\n")
      emit_tp(fields)
      plain("\n\n")
      render_quoted_comment
      plain("#{"-" * 50}\n\n")
      emit_tp(handy_links)
      plain("\n\n")
      render_links_section(links)
      plain("\n")
      emit_tp(report_abuse)
    end

    private

    def render_quoted_comment
      return unless @comment.comment

      trusted_html(@comment.comment.tp.html_to_ascii)
      plain("\n\n")
    end
  end
end
