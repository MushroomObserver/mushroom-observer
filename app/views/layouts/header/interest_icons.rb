# frozen_string_literal: true

# Page-title-bar interest-icons block — the cluster of three icons
# (`watch` / `halfopen` / `ignore`) on the upper-right of a show
# page that lets the viewer subscribe / unsubscribe to email alerts
# about the object. Three states:
#
# - `:watching` — big watch eye; click small `halfopen` → default,
#   click small `ignore` → ignoring.
# - `:ignoring` — big ignore eye; click small `watch` → watching,
#   click small `halfopen` → default.
# - default   — small watch eye + small ignore eye, no big eye.
#
# Rendered into `content_for(:interest_icons)` by
# `Views::FullPageBase::Icons#add_interest_icons`. Always emits
# a `<ul>` — empty when no user, so the parent flex layout is
# consistent regardless of login state.
module Views::Layouts
  class Header::InterestIcons < Views::Base
    prop :user, _Nilable(::User), default: nil
    prop :object, ::AbstractModel

    def view_template
      ul(class: "nav flex-bar interest-eyes h4 my-0") do
        render_icons if @user
      end
    end

    private

    def render_icons
      case @user.interest_in(@object)
      when :watching then render_watching
      when :ignoring then render_ignoring
      else render_default
      end
    end

    def type
      @type ||= @object.type_tag
    end

    def render_watching
      icon_li(:big, "watch", :interest_watching)
      link_li(0, "halfopen", :interest_default_help)
      link_li(-1, "ignore", :interest_ignore_help)
    end

    def render_ignoring
      icon_li(:big, "ignore", :interest_ignoring)
      link_li(1, "watch", :interest_watch_help)
      link_li(0, "halfopen", :interest_default_help)
    end

    def render_default
      link_li(1, "watch", :interest_watch_help)
      link_li(-1, "ignore", :interest_ignore_help)
    end

    def icon_li(size, kind, alt_key)
      li { interest_icon(size, kind, alt_key) }
    end

    def link_li(state, kind, alt_key)
      li { interest_link(state:) { interest_icon(:small, kind, alt_key) } }
    end

    def interest_link(state:, &block)
      # `data-turbo-stream="true"` as a literal string (not boolean)
      # so Phlex emits `data-turbo-stream="true"` rather than the
      # bare-attribute / empty-value form a `true` boolean would
      # produce. Matches what Rails' `link_to(..., data: { turbo_stream:
      # true })` rendered before the conversion.
      a(href: set_interest_path(id: @object.id,
                                type: @object.class.name,
                                state: state),
        data: { turbo_stream: "true" }, &block)
    end

    # `size` is `:big` (state-indicator icon, no link wrapper) or
    # `:small` (clickable variants inside an `<a>`). The filename is
    # `<kind>2.png` for big, `<kind>3.png` for small — matches the
    # asset naming pre-conversion.
    def interest_icon(size, kind, alt_key)
      alt = alt_key.l(object: type.l)
      suffix = size == :big ? "2" : "3"
      img(src: asset_path("#{kind}#{suffix}.png"),
          alt: alt, class: "interest_#{size}", title: alt)
    end
  end
end
