# frozen_string_literal: true

# Notify observation owner when their observation is added to or
# removed from an occurrence.
class Views::Mailers::OccurrenceChangeMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :sender, _Nilable(::User), default: nil
  prop :observation, ::Observation
  prop :action, ::String

  class Html < self
    include Views::Mailers::FieldsOnlyBody
  end

  class Text < self
    include Views::Mailers::FieldsOnlyBody
  end

  private

  # `sender` is nil when the change was made by an automated process
  # rather than a logged-in user. Attribute those to the site itself.
  def intro
    :"email_occurrence_#{@action}_intro".l(
      name: @observation.unique_format_name(@receiver),
      user: @sender&.legal_name || :app_title.t
    )
  end

  def fields
    text = "*#{:Time.l}:* #{Time.zone.now.email_time}\n"
    text += "*#{:By.l}:* #{@sender.legal_name} (#{@sender.login})\n" if @sender
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
