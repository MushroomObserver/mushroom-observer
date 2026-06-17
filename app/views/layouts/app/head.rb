# frozen_string_literal: true

module Views::Layouts::App
  # `<head>` contents for the application layout. Renders the GTM
  # bootstrap (production only), meta / link / `<title>` tags, the
  # favicons partial, the canonical URL link (when set), CSRF tag,
  # OpenGraph tags, theme stylesheets, importmap tags, and any
  # per-page `@header` chunk.
  class Head < Views::Base
    register_value_helper :action_cable_meta_tag
    register_value_helper :auto_discovery_link_tag
    register_value_helper :csrf_meta_tag
    register_value_helper :stylesheet_link_tag
    register_value_helper :javascript_importmap_tags
    register_value_helper :escape_once

    prop :css_theme, ::String
    prop :canonical_url, _Nilable(::String), default: nil
    prop :header, _Nilable(::String), default: nil

    OG_DESCRIPTION =
      "Mushroom Observer is a forum where amateur and professional " \
      "mycologists can come together and celebrate their common " \
      "passion for mushrooms by discussing and sharing photos of " \
      "mushroom sightings from around the world."
    OG_IMAGE =
      "https://mushroomobserver.org/images/facebook_icon.png"

    GTM_SCRIPT = <<~JS
      (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
      new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
      j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
      'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
      })(window,document,'script','dataLayer','GTM-PJKJR59');
    JS

    def view_template
      render_gtm_bootstrap if Rails.env.production?
      render_meta_tags
      render_title
      render(Favicons.new)
      render_canonical_link if @canonical_url
      trusted_html(csrf_meta_tag)
      render_og_tags
      render_stylesheets
      trusted_html(javascript_importmap_tags)
      trusted_html(@header) if @header.present?
    end

    private

    def render_gtm_bootstrap
      script { trusted_html(::ActiveSupport::SafeBuffer.new(GTM_SCRIPT)) }
    end

    def render_meta_tags
      # Phlex blocks the `http-equiv` attribute by name. Emit raw.
      trusted_html(::ActiveSupport::SafeBuffer.new(
                     %(<meta http-equiv="Content-Type" ) +
                     %(content="text/html;charset=utf-8" />)
                   ))
      meta(name: "viewport",
           content: "width=device-width, initial-scale=1")
      meta(name: "turbo-refresh-scroll", content: "preserve")
      meta(name: "turbo-prefetch", content: "false")
      trusted_html(action_cable_meta_tag)
      trusted_html(auto_discovery_link_tag(
                     :rss, activity_logs_rss_path, { title: :app_rss.l }
                   ))
    end

    def render_title
      # `content_for(:document_title)` returns a SafeBuffer where
      # plain `'` was concat-escaped to `&#39;`. `plain(...)` would
      # then re-escape the `&` to `&amp;`. Write the safe piece raw.
      title do
        plain("#{:app_title.l}: ")
        trusted_html(content_for(:document_title))
      end
    end

    def render_canonical_link
      link(rel: "canonical", href: escape_once(@canonical_url))
    end

    def render_og_tags
      meta(property: "og:image", content: OG_IMAGE)
      meta(property: "og:title", content: "Mushroom Observer")
      meta(property: "og:description", content: OG_DESCRIPTION)
    end

    def render_stylesheets
      trusted_html(stylesheet_link_tag(@css_theme, media: "screen"))
      trusted_html(stylesheet_link_tag(@css_theme, media: "print"))
      render(UserSpecificCss.new(user: current_user))
    end
  end
end
