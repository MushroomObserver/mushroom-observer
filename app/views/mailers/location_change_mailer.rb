# frozen_string_literal: true

# Notify user of change in location description. The most complex
# mailer converted: a diff between two ObjectChange clones, split
# into one_liners (single-line "X changed to Y" fields) and
# many_liners (multi-paragraph note fields, each in its own boxed
# div). `email_type`/`watching` are computed by the mailer (they
# need permission-table queries), not here.
class Views::Mailers::LocationChangeMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :sender, _Nilable(::User), default: nil
  prop :time, ::ActiveSupport::TimeWithZone
  prop :loc_change, ::ObjectChange
  prop :desc_change, ::ObjectChange
  prop :watching, _Boolean
  prop :email_type, _Nilable(::String), default: nil

  ONE_LINER_FIELDS = [
    [:Name, :display_name, :name],
    [:email_field_north, :north, :north],
    [:email_field_south, :south, :south],
    [:email_field_east, :east, :east],
    [:email_field_west, :west, :west],
    [:show_location_highest, :high, :high],
    [:show_location_highest, :low, :low]
  ].freeze

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
      emit_tp(one_liners) if one_liners.present?
      many_liners.each { |label, value| render_many_liner(label, value) }
      emit_tp(handy_links)
      render_links_section(links)
    end

    def render_many_liner(label, value)
      emit_tp("*#{label} #{now_label}:*")
      render_message_box { trusted_html(value.tp) }
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      gap
      emit_tp(fields)
      gap
      render_one_liners
      render_many_liners
      newline
      emit_tp(handy_links)
      gap
      render_links_section(links)
      newline
    end

    private

    def render_many_liners
      many_liners.each_with_index do |(label, value), index|
        newline if index.positive?
        render_many_liner(label, value)
      end
    end

    def render_one_liners
      return if one_liners.blank?

      emit_tp(one_liners)
      gap
    end

    def render_many_liner(label, value)
      plain("#{label} #{now_label}:\n")
      dashes_line
      trusted_html(value.tp.html_to_ascii)
      newline
      dashes_line
    end
  end

  private

  def new_loc = @loc_change.new_clone
  def old_loc = @loc_change.old_clone
  def new_desc = @desc_change.new_clone
  def old_desc = @desc_change.old_clone
  def now_label = :email_field_is_now.l

  def intro
    name = "#{Location.user_format(@receiver, old_loc.name)} (#{new_loc.id})"
    :email_object_change_intro.l(type: :location, name:)
  end

  def fields
    text = "*#{:Time.l}:* #{@time.email_time}\n"
    text += "*#{:By.l}:* #{@sender.legal_name} (#{@sender.login})\n" if @sender
    text
  end

  def one_liners
    simple_one_liners + license_liner
  end

  # Joins already-built lines with "\n", adding exactly one trailing
  # newline when there's content — keeps the separator a join
  # concern instead of baking it into every line string, and lets
  # an empty `lines` collapse to "" (no orphan blank line) instead
  # of always emitting a trailing newline regardless of content.
  def terminate_lines(lines)
    return "" if lines.empty?

    "#{lines.join("\n")}\n"
  end

  def simple_one_liners
    terminate_lines(ONE_LINER_FIELDS.filter_map do |key, attr, cmp|
      one_liner(key, attr, cmp)
    end)
  end

  def one_liner(key, attr, compare_attr)
    if new_loc.public_send(compare_attr) == old_loc.public_send(compare_attr)
      return nil
    end

    "*#{key.l} #{now_label}:* #{new_loc.public_send(attr)}"
  end

  def license_liner
    return "" unless new_desc && new_desc.license_id != old_desc&.license_id

    "*#{:license.l} #{now_label}:* #{new_desc.license.display_name}\n"
  end

  def many_liners
    return [] unless new_desc

    LocationDescription.all_note_fields.filter_map do |field|
      old_val = old_desc&.send(field)
      new_val = new_desc.send(field)
      next if new_val == old_val

      [:"form_locations_#{field}".t, new_val]
    end
  end

  def handy_links
    base = :email_handy_links.l
    return base unless @email_type

    :"email_object_change_reason_#{@email_type}".l(type: :location).
      sub(/\n*\z/, "\n#{base}")
  end

  def links
    [[:email_links_show_object.t(type: :location), show_object_url],
     [:email_links_not_interested.t(type: :location), not_interested_url],
     *stop_sending_link,
     [:email_links_change_prefs.t,
      "#{MO.http_domain}/account/preferences/edit"],
     [:email_links_latest_changes.t, MO.http_domain]]
  end

  def show_object_url = "#{MO.http_domain}/locations/#{new_loc.id}"

  def not_interested_url
    "#{MO.http_domain}/interests/set_interest?id=#{new_loc.id}" \
      "&type=Location&user=#{@receiver.id}&state=-1"
  end

  def stop_sending_link
    return [] unless @email_type && @email_type != "interest"
    return [] if @watching

    [[:email_links_stop_sending.t,
      "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
      "?type=locations_#{@email_type}"]]
  end
end
