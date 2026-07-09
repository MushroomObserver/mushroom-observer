# frozen_string_literal: true

# Notify user of change in observation (or its destruction, when
# `observation` is nil). Deviates from both shared modules
# (conditional "changes" section, conditional notes box only
# reachable when there IS an observation and its notes changed), so
# this writes its own view_template.
class Views::Mailers::ObservationChangeMailer < Views::Mailers::Base
  include Views::Mailers::ObservationLinks

  prop :subject, ::String
  prop :receiver, ::User
  prop :sender, _Nilable(::User), default: nil
  prop :observation, _Nilable(::Observation), default: nil
  prop :note, _Nilable(::String), default: nil
  prop :time, ::ActiveSupport::TimeWithZone

  SIMPLE_CHANGE_KEYS = {
    "thumb_image_id" => :email_field_changed_thumbnail,
    "added_image" => :email_field_added_images,
    "removed_image" => :email_field_removed_images
  }.freeze

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      emit_tp(fields)
      emit_tp(changes)
      render_notes_box
      emit_tp(handy_links)
      render_links_section(links)
    end

    def render_notes_box
      return unless notes_changed?

      render_message_box do
        trusted_html(@observation.notes_export_formatted.tp)
      end
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      gap
      emit_tp(fields)
      render_observation_section
      emit_tp(handy_links)
      gap
      render_links_section(links)
      newline
    end

    private

    def render_observation_section
      unless @observation
        gap
        return
      end

      newline
      emit_tp(changes)
      gap
      render_notes_and_divider
    end

    def render_notes_and_divider
      return unless notes_changed?

      trusted_html(@observation.notes_export_formatted.tp.html_to_ascii)
      divider
    end
  end

  private

  def intro
    if @observation
      :email_object_change_intro.l(
        type: :observation,
        name: @observation.unique_format_name(@receiver)
      )
    else
      :email_observation_destroyed_intro.l
    end
  end

  def fields
    text = @observation ? "" : "*#{:Observation.l}:* #{@note}\n"
    text += "*#{:Time.l}:* #{@time.email_time}\n"
    text += "*#{:By.l}:* #{@sender.legal_name} (#{@sender.login})\n" if @sender
    text
  end

  def notes_changed?
    @observation && @note&.split(",")&.include?("notes")
  end

  def changes
    return "" unless @observation && @note

    text = @note.split(",").filter_map { |field| change_line(field) }.join
    text += "*#{:Notes.l} #{now_label}:*\n" if notes_changed?
    text
  end

  def now_label = :email_field_is_now.l

  def change_line(field)
    case field
    when "date"
      "*#{:Date.l} #{now_label}:* #{@observation.when.email_date}\n"
    when "location"
      "*#{:Location.l} #{now_label}:* #{@observation.place_name(@receiver)}\n"
    when "specimen" then specimen_line
    when "is_collection_location" then collection_location_line
    else simple_change_line(field)
    end
  end

  def simple_change_line(field)
    key = SIMPLE_CHANGE_KEYS[field]
    key ? "*#{key.l}.*\n" : nil
  end

  def specimen_line
    key = if @observation.specimen
            :email_field_specimen_available
          else
            :email_field_no_specimen_available
          end
    "*#{key.l}.*\n"
  end

  def collection_location_line
    key = if @observation.is_collection_location
            :email_field_collection_location
          else
            :email_field_collection_not_location
          end
    "*#{key.l}.*\n"
  end

  def handy_links = :email_handy_links.l

  def links
    [*observation_links, [:email_links_latest_changes.t, MO.http_domain]]
  end

  def observation_links
    return [] unless @observation

    [[:email_links_show_object.t(type: :observation), show_object_url],
     [:email_links_post_comment.t, post_comment_url],
     [:email_links_not_interested.t(type: :observation), not_interested_url]]
  end
end
