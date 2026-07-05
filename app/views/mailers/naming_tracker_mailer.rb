# frozen_string_literal: true

# Notify user someone has observed a name they are interested in.
# Both intro and fields use the placeholder-token + splice_html
# technique (like VerifyAccountMailer/VerifyAPIKeyMailer), so this
# writes its own view_template.
class Views::Mailers::NamingTrackerMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :observation, ::Observation
  prop :naming, ::Naming

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      trusted_html(intro)
      trusted_html(fields)
      emit_tp(handy_links)
      render_links_section(links)
      emit_tp(report_abuse)
    end
  end

  class Text < self
    def view_template
      trusted_html(intro.html_to_ascii)
      gap
      trusted_html(fields.html_to_ascii)
      gap
      emit_tp(handy_links)
      gap
      render_links_section(links)
      newline
      emit_tp(report_abuse)
    end
  end

  private

  def observation_url = "#{MO.http_domain}/#{@observation.id}"
  def name_url = "#{MO.http_domain}/names/#{@naming.name_id}"
  def observer_url = "#{MO.http_domain}/users/#{@observation.user_id}"
  def identifier_url = "#{MO.http_domain}/users/#{@naming.user_id}"

  def intro
    base = :email_naming_for_tracker_intro.tp(obs: "xxx", name: "yyy")
    spliced = splice_html(
      base, /xxx/, capture { link_to(:observation.l, observation_url) }
    )
    splice_html(
      spliced, /yyy/,
      capture { link_to(@naming.user_format_name(@receiver).t, name_url) }
    )
  end

  def fields
    base = fields_text.tp
    spliced = splice_html(
      base, /xxx/, capture do
                     link_to(@observation.user.legal_name, observer_url)
                   end
    )
    splice_html(
      spliced, /yyy/,
      capture { link_to(@naming.user.legal_name, identifier_url) }
    )
  end

  def fields_text
    text = "*#{:Observer.l}:* xxx\n"
    text += "*#{:Identifier.l}:* yyy\n"
    text += specimen_line
    text += "*#{:email_field_image_count.l}:* #{@observation.images.length}\n"
    text
  end

  def specimen_line
    key = if @observation.specimen
            :show_observation_specimen_available
          else
            :show_observation_specimen_not_available
          end
    "*#{key.l}*\n"
  end

  def handy_links = :email_handy_links.l

  def links
    [[:email_links_show_object.t(type: :observation), observation_url],
     [:email_links_show_observer.t, observer_url],
     *identifier_link,
     [:email_links_disable_tracking.t(type: :name),
      "#{MO.http_domain}/name/email_tracking/#{@naming.name_id}"],
     [:email_links_your_interests.t, "#{MO.http_domain}/interests"],
     [:email_links_latest_changes.t, MO.http_domain]]
  end

  def identifier_link
    return [] if @observation.user_id == @naming.user_id

    [[:email_links_show_identifier.t, identifier_url]]
  end
end
