# frozen_string_literal: true

module Views::Controllers::Theme
  # One species row on a theme detail page. Renders the textile
  # translation referenced by the row, with a link to the row's
  # image substituted for the `[link]` placeholder. Optionally
  # wraps the body in a `<p><span class="list-line-N">…</span></p>`
  # for the bottom rows that demo list-line colours.
  class SpeciesParagraph < Views::Base
    prop :row, SpeciesRow

    def view_template
      body = build_body
      if @row.list_line
        p { span(class: @row.list_line) { trusted_html(body) } }
      else
        trusted_html(body)
      end
    end

    private

    def build_body
      link_html = capture { render_link }
      textile = @row.key.send(@row.textile_method, link: "XXX")
      ::ActiveSupport::SafeBuffer.new(textile.to_s.sub("XXX", link_html))
    end

    def render_link
      label = @row.raw_link_label ? @row.name : "**__#{@row.name}__**"
      link_to(image_path(id: @row.image_id)) { trusted_html(label.t) }
    end
  end
end
