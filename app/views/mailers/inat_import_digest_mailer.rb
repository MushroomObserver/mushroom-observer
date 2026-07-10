# frozen_string_literal: true

# Digest of the observations an iNat import added that match names the
# receiver follows — one email instead of a per-naming flood (#4757).
class Views::Mailers::InatImportDigestMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :namings, ::Array

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      trusted_html(intro)
      trusted_html(observation_list)
      emit_tp(handy_links)
      render_links_section(links)
    end
  end

  class Text < self
    def view_template
      trusted_html(intro.html_to_ascii)
      gap
      trusted_html(observation_list.html_to_ascii)
      gap
      emit_tp(handy_links)
      gap
      render_links_section(links)
    end
  end

  private

  def intro
    :email_inat_import_digest_intro.tp(count: grouped.size)
  end

  # The receiver's matching namings grouped by observation, id-ordered.
  def grouped
    @grouped ||= @namings.group_by(&:observation).sort_by { |obs, _| obs.id }
  end

  # Built via capture so the pieces (link_to output, textile-rendered
  # names) stay a safe buffer; html_to_ascii converts it for the text part.
  def observation_list
    capture do
      ul do
        grouped.each do |obs, namings|
          li do
            emit_observation_row(obs, namings)
          end
        end
      end
    end
  end

  # HTML links the id; text shows the name(s) then the bare URL, since
  # html_to_ascii would otherwise drop the href (matching how the shared
  # links section renders "label: url" in text).
  def emit_observation_row(obs, namings)
    url = "#{MO.http_domain}/#{obs.id}"
    if html?
      link_to("##{obs.id}", url)
      plain(": ")
      emit_proposed_names(namings)
    else
      emit_proposed_names(namings)
      plain(": #{url}")
    end
  end

  # format_name already returns rendered (safe) markup; emit each raw with
  # comma separators (safe_join isn't available in Phlex views).
  def emit_proposed_names(namings)
    names = namings.map { |n| n.format_name(@receiver).t }.uniq
    names.each_with_index do |name, i|
      plain(", ") if i.positive?
      trusted_html(name)
    end
  end

  def handy_links = :email_handy_links.l

  # Manage the interests/trackers that drive this digest, and the site's
  # latest changes. (/account/no_email needs a specific email-type param
  # and doesn't map to a digest, so it's intentionally omitted — /interests
  # is where a user tunes what produces these.)
  def links
    [[:email_links_your_interests.t, "#{MO.http_domain}/interests"],
     [:email_links_latest_changes.t, MO.http_domain]]
  end
end
