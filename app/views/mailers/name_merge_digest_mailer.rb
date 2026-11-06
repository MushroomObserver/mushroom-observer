# frozen_string_literal: true

# One email per user about a Name merge: the observations they follow whose
# namings moved to the surviving name, and whether their tracker of the
# merged-away name moved with it. See Name::MergeDigest.
class Views::Mailers::NameMergeDigestMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :sender, _Nilable(::User)
  prop :old_name, ::String
  prop :new_name, ::Name
  prop :namings, ::Array
  prop :total_observations, ::Integer
  prop :tracker_moved, _Boolean

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      render_observations
      render_tracker
      emit_tp(handy_links)
      render_links_section(links)
    end

    def render_observations
      return if @namings.empty?

      emit_tp(observations_intro)
      trusted_html(observation_list)
      render_truncation_note
    end

    def render_tracker
      return unless @tracker_moved

      emit_tp(tracker_note)
      p { link_to(:email_name_merge_digest_edit_tracker.l, edit_tracker_url) }
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      gap
      render_observations
      render_tracker
      emit_tp(handy_links)
      gap
      render_links_section(links)
    end

    private

    def render_observations
      return if @namings.empty?

      emit_tp(observations_intro)
      gap
      trusted_html(observation_list.html_to_ascii)
      gap
      render_truncation_note
    end

    def render_tracker
      return unless @tracker_moved

      emit_tp(tracker_note)
      gap
      plain("#{:email_name_merge_digest_edit_tracker.l}: #{edit_tracker_url}")
      gap
    end
  end

  private

  def intro
    :email_name_merge_digest_intro.l(
      user: @sender&.legal_name || :email_name_merge_digest_admin.l,
      old: @old_name, new: new_display_name
    )
  end

  def new_display_name = @new_name.display_name(@receiver)

  def observations_intro
    :email_name_merge_digest_observations.l(count: @total_observations,
                                            new: new_display_name)
  end

  def tracker_note
    :email_name_merge_digest_tracker.l(old: @old_name, new: new_display_name)
  end

  def edit_tracker_url
    edit_tracker_of_name_url(@new_name.id, host: MO.http_domain)
  end

  def truncated?
    grouped.size < @total_observations
  end

  def render_truncation_note
    return unless truncated?

    emit_tp(:email_name_merge_digest_truncated.l(shown: grouped.size,
                                                 count: @total_observations))
    gap
  end

  def grouped
    @grouped ||= @namings.map(&:observation).uniq.sort_by(&:id)
  end

  # Built via capture so the pieces stay a safe buffer; html_to_ascii
  # converts it for the text part.
  def observation_list
    capture do
      ul do
        grouped.each { |obs| li { emit_observation_row(obs) } }
      end
    end
  end

  # HTML links the id; text shows the name then the bare URL, since
  # html_to_ascii would otherwise drop the href.
  def emit_observation_row(obs)
    if html?
      link_to("##{obs.id}", obs.show_url)
      plain(": ")
      trusted_html(obs.format_name(@receiver).t)
    else
      trusted_html(obs.format_name(@receiver).t)
      plain(": #{obs.show_url}")
    end
  end

  def handy_links = :email_handy_links.l

  def links
    [[:email_links_your_interests.l, "#{MO.http_domain}/interests"],
     [:email_links_latest_changes.l, MO.http_domain]]
  end
end
