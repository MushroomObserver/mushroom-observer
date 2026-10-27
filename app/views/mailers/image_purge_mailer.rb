# frozen_string_literal: true

# The images removed from the receiver's content by an image purge, each
# with what showed it and where the photo can still be seen.
class Views::Mailers::ImagePurgeMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :entries, ::Array
  prop :holder, ::String

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        emit_tp(intro)
        ul { @entries.each { |entry| li { render_entry(entry) } } }
      end
    end

    private

    def render_entry(entry)
      plain(entry_label(entry))
      plain(": ")
      entry[:content].each_with_index do |(label, url), i|
        plain(", ") if i.positive?
        a(href: url) { label }
      end
      br
      render_source(entry[:source_url])
    end

    def render_source(url)
      return plain(:image_purge_email_no_source.l) unless url

      plain(:image_purge_email_source.l)
      whitespace
      a(href: url) { url }
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      gap
      @entries.each { |entry| render_entry(entry) }
    end

    private

    def render_entry(entry)
      trusted_text("* #{entry_label(entry)}\n")
      entry[:content].each do |label, url|
        trusted_text("  #{label}: #{url}\n")
      end
      source = entry[:source_url]
      trusted_text("  #{source_line(source)}\n")
    end

    def source_line(url)
      return :image_purge_email_no_source.l unless url

      "#{:image_purge_email_source.l} #{url}"
    end
  end

  private

  def intro
    :email_image_purge_intro.l(holder: @holder, count: @entries.size)
  end

  def entry_label(entry)
    "#{:image.ti} #{entry[:image_id]} (#{entry[:copyright_holder]})"
  end
end
