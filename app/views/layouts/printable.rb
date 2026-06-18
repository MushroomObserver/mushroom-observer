# frozen_string_literal: true

# The print-friendly application layout. Selected by
# `Views::FullPageBase#around_template` when
# `session[:layout] == "printable"` (set by
# `ApplicationController#change_theme_to` when the user picks the
# "printable" theme).
#
# Doesn't extend `Views::FullPageBase` on purpose:
# `Views::FullPageBase#around_template` is the one that picks the
# layout, and re-entering it from the layout itself would recurse.
# Layout classes sit one level above the chain `Views::FullPageBase`
# wraps.
module Views::Layouts
  class Printable < Components::Base
    register_value_helper :auto_discovery_link_tag

    PRINT_STYLE = <<~CSS
      body, p, ol, ul, td {
        font-family: verdana, arial, helvetica, sans-serif;
        font-size:   9px;
        line-height: 15px;
        margin-top: 0px;
        margin-left: 0px;
        margin-right: 0px;
      }

      body {
        margin-bottom: 0px;
      }

      .break {
        page-break-before: always;
      }

      table {
        page-break-inside:avoid;
      }
    CSS

    OG_DESCRIPTION =
      "Mushroom Observer is a forum where amateur and professional " \
      "mycologists can come together and celebrate their common " \
      "passion for mushrooms by discussing and sharing photos of " \
      "mushroom sightings from around the world."

    def view_template(&block)
      doctype
      html(lang: "en") do
        head { render_head }
        body(&block)
      end
    end

    private

    def render_head
      meta(charset: "utf-8")
      trusted_html(auto_discovery_link_tag(
                     :rss, activity_logs_rss_path, { title: :app_rss.l }
                   ))
      title do
        plain("#{:app_title.l}: ")
        trusted_html(content_for(:document_title))
      end
      link(rel: "SHORTCUT ICON", href: "/favicon.ico?20220116")
      meta(property: "og:image",
           content: "https://mushroomobserver.org/images/facebook_icon.png")
      meta(property: "og:title", content: "Mushroom Observer")
      meta(property: "og:description", content: OG_DESCRIPTION)
      style { trusted_html(::ActiveSupport::SafeBuffer.new(PRINT_STYLE)) }
    end
  end
end
