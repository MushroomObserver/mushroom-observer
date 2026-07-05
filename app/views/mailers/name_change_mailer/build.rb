# frozen_string_literal: true

module Views::Mailers::NameChangeMailer
  # Notify user of change in name description. Same diff-rendering shape
  # as LocationChangeMailer (one_liners + many_liners against an
  # ObjectChange pair), plus: a brand-new-Name branch (no one_liners/
  # many_liners at all), several Name-specific one-liner toggles
  # (deprecated/accepted, misspelled/not_misspelled, correct_spelling),
  # and a `classification` diff appended to many_liners (that field
  # lives on Name, not NameDescription, since discussion #4163).
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User
    prop :sender, _Nilable(::User), default: nil
    prop :time, ::ActiveSupport::TimeWithZone
    prop :name_change, ::ObjectChange
    prop :desc_change, ::ObjectChange
    prop :review_status, _Nilable(::String), default: nil
    prop :watching, _Boolean
    prop :email_type, _Nilable(::String), default: nil

    SIMPLE_ONE_LINERS = [
      [:Authority, :author, :author],
      [:Citation, :citation, :citation],
      [:Rank, :rank, :rank]
    ].freeze

    STATUS_LINERS = [
      [:deprecated_change?, :Name, :Deprecated],
      [:accepted_change?, :Status, :Accepted],
      [:misspelled_change?, :Status, :Misspelled],
      [:not_misspelled_change?, :Status, :Not_misspelled]
    ].freeze

    private

    def new_name = @name_change.new_clone
    def old_name = @name_change.old_clone
    def new_desc = @desc_change.new_clone
    def old_desc = @desc_change.old_clone
    def now_label = :email_field_is_now.l

    def intro
      if old_name
        name = "#{old_name.user_display_name(@receiver)} (#{new_name.id})"
        :email_object_change_intro.l(type: :name, name:)
      else
        name = "#{new_name.user_display_name(@receiver)} (#{new_name.id})"
        :email_object_new_intro.l(type: :name, name:)
      end
    end

    def fields
      text = "*#{:Time.l}:* #{@time.email_time}\n"
      if @sender
        text += "*#{:By.l}:* #{@sender.legal_name} (#{@sender.login})\n"
      end
      text
    end

    def one_liners
      return "" unless old_name

      real_text_name_liner + simple_one_liners + license_liner +
        review_status_liner + status_liners + correct_spelling_liner
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
      terminate_lines(SIMPLE_ONE_LINERS.filter_map do |key, attr, cmp|
        one_liner(key, attr, cmp)
      end)
    end

    def real_text_name_liner
      return "" if new_name.user_real_text_name(@receiver) ==
                   old_name.user_real_text_name(@receiver)

      "*#{:Name.l} #{now_label}:* #{new_name.user_real_text_name(@receiver)}\n"
    end

    def one_liner(key, attr, compare_attr)
      return nil if new_name.public_send(compare_attr) ==
                    old_name.public_send(compare_attr)

      "*#{key.l} #{now_label}:* #{new_name.public_send(attr)}"
    end

    def license_liner
      return "" unless new_desc && new_desc.license_id != old_desc&.license_id

      "*#{:License.l} #{now_label}:* #{new_desc.license.display_name}\n"
    end

    def review_status_liner
      return "" unless @review_status && @review_status != "no_change"

      "*#{:Reviewed.l} #{now_label}:* #{@review_status}\n"
    end

    def status_liners
      terminate_lines(STATUS_LINERS.filter_map do |predicate, key, value|
        next unless send(predicate)

        "*#{key.l} #{now_label}:* #{value.l}"
      end)
    end

    def deprecated_change? = new_name.deprecated && !old_name.deprecated
    def accepted_change? = !new_name.deprecated && old_name.deprecated

    def misspelled_change?
      !new_name.correct_spelling_id && old_name.correct_spelling_id
    end

    def not_misspelled_change?
      new_name.correct_spelling_id && !old_name.correct_spelling_id
    end

    def correct_spelling_liner
      return "" if new_name.correct_spelling_id == old_name.correct_spelling_id

      new_spell = if new_name.correct_spelling
                    new_name.correct_spelling.user_display_name(@receiver)
                  else
                    "--"
                  end
      "*#{:Correct_spelling.l} #{now_label}:* #{new_spell} " \
        "(#{new_name.correct_spelling_id}, #{old_name.correct_spelling_id})\n"
    end

    def many_liners
      return [] unless old_name

      note_liners + classification_liner
    end

    def note_liners
      return [] unless new_desc

      NameDescription.all_note_fields.filter_map do |field|
        old_val = old_desc&.send(field)
        new_val = new_desc.send(field)
        next if new_val == old_val

        [:"form_names_#{field}".t, new_val]
      end
    end

    def classification_liner
      return [] if new_name.classification == old_name.classification

      [[:form_names_classification.t, new_name.classification]]
    end

    def handy_links
      base = :email_handy_links.l
      return base unless @email_type

      :"email_object_change_reason_#{@email_type}".l(type: :name).
        sub(/\n*\z/, "\n#{base}")
    end

    def links
      [[:email_links_show_object.t(type: :name), show_object_url],
       [:email_links_not_interested.t(type: :name), not_interested_url],
       *stop_sending_link,
       [:email_links_change_prefs.t,
        "#{MO.http_domain}/account/preferences/edit"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end

    def show_object_url = "#{MO.http_domain}/names/#{new_name.id}"

    def not_interested_url
      "#{MO.http_domain}/interests/set_interest?id=#{new_name.id}" \
        "&type=Name&user=#{@receiver.id}&state=-1"
    end

    def stop_sending_link
      return [] unless @email_type && @email_type != "interest"
      return [] if @watching

      [[:email_links_stop_sending.t,
        "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
        "?type=names_#{@email_type}"]]
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
      emit_tp(fields)
      emit_tp(one_liners) if one_liners.present?
      many_liners.each { |label, value| render_many_liner(label, value) }
      emit_tp(handy_links)
      render_links_section(links)
    end

    def render_many_liner(label, value)
      emit_tp("*#{label} #{now_label}:*")
      render_message_box { trusted_html(value.to_s.tp) }
    end
  end

  class Text < Build
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
      if one_liners.present?
        emit_tp(one_liners)
        gap
      else
        newline
      end
    end

    def render_many_liner(label, value)
      plain("#{label} #{now_label}:\n")
      dashes_line
      trusted_html(value.to_s.tp.html_to_ascii)
      newline
      dashes_line
    end
  end
end
