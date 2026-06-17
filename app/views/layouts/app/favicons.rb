# frozen_string_literal: true

module Views::Layouts::App
  # Favicon + Apple-touch-icon + web manifest `<link>` / `<meta>`
  # block for the application layout's `<head>`.
  class Favicons < Views::Base
    PNG_SIZES = %w[96x96 32x32 16x16].freeze
    APPLE_SIZES = %w[57x57 72x72 76x76 114x114 152x152].freeze

    def view_template
      PNG_SIZES.each do |size|
        link(rel: "icon", type: "image/png", sizes: size,
             href: asset_path("favicon-#{size}.png"))
      end
      link(rel: "icon", type: "image/svg+xml",
           href: asset_path("favicon.svg"))
      link(rel: "shortcut icon", href: asset_path("favicon.ico"))
      APPLE_SIZES.each do |size|
        link(rel: "apple-touch-icon", sizes: size,
             href: asset_path("apple-touch-icon-#{size}.png"))
      end
      link(rel: "apple-touch-icon", sizes: "180x180",
           href: asset_path("apple-touch-icon.png"))
      meta(name: "apple-mobile-web-app-title", content: "MushroomObserver")
      link(rel: "manifest", href: asset_path("site.webmanifest"))
    end
  end
end
