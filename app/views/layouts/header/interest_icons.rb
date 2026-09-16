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
# `Views::FullPageBase::Icons#add_interest_icons`. A `<div
# class="btn-toolbar" role="toolbar">` — a toolbar of borderless
# icon buttons, not a navigation list. Always emits the wrapper —
# empty when no user, so the parent flex layout is consistent
# regardless of login state.
module Views::Layouts
  class Header::InterestIcons < Views::Base
    # Bootstrap's default tooltip `container: false` inserts the
    # floating tooltip as the trigger's next DOM sibling -- trapped
    # inside the tight `.btn` wrapper here, it gets clipped and
    # mis-stacked. Anchoring it to the whole toolbar instead gives it
    # room (same fix as `ImageFragment::VoteInterface#tooltip_container`).
    TOOLTIP_CONTAINER = ".interest-eyes"

    prop :user, _Nilable(::User), default: nil
    prop :object, ::AbstractModel

    def view_template
      div(class: "btn-toolbar interest-eyes h4 my-0", role: "toolbar",
          aria: { label: :app_interest_icons_label.l }) do
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
      icon_item(:big, "watch", :interest_watching)
      destroy_item("halfopen", :interest_default_help)
      update_item(-1, "ignore", :interest_ignore_help)
    end

    def render_ignoring
      icon_item(:big, "ignore", :interest_ignoring)
      update_item(1, "watch", :interest_watch_help)
      destroy_item("halfopen", :interest_default_help)
    end

    def render_default
      create_item(1, "watch", :interest_watch_help)
      create_item(-1, "ignore", :interest_ignore_help)
    end

    # Inert state indicator, not a control -- `tag: :span` + `.disabled`
    # (not `Button(type: :post/...)`, which are form-submitting
    # controls) gives it a `.btn` box like the two clickable buttons
    # beside it, so it doesn't render as a bare, oversized, unpadded
    # image alongside them. `variant: :outline` (bordered), not
    # `:link` (borderless, same as the two clickable buttons) -- the
    # border is what visually marks this one as "your current state",
    # not clickable.
    def icon_item(size, kind, alt_key)
      Button(tag: :span, variant: :outline, class: "disabled") do
        interest_icon(size, kind, alt_key)
      end
    end

    # No existing `Interest` row -- `interests_path` has no `:id`
    # segment, so both `id:` and `state:` ride as form params.
    def create_item(state, kind, alt_key)
      params = { type: @object.class.name, id: @object.id, state: }
      interest_button(:post, interests_path, kind:, alt_key:, params:)
    end

    # An `Interest` row already exists and is flipping to the other
    # non-default state -- `:id` in `interest_path` is the WATCHED
    # OBJECT's id, matching what `InterestsController#update` reads
    # from `params[:id]` (not the `Interest` row's id).
    def update_item(state, kind, alt_key)
      params = { type: @object.class.name, state: }
      interest_button(:patch, interest_path(@object.id), kind:, alt_key:,
                                                         params:)
    end

    # Returning to the default (no-opinion) state destroys the
    # `Interest` row outright -- no `state:` param needed, the DELETE
    # verb already says what's happening.
    def destroy_item(kind, alt_key)
      params = { type: @object.class.name }
      interest_button(:delete, interest_path(@object.id), kind:, alt_key:,
                                                          params:)
    end

    # `variant: :link` (Bootstrap's own `.btn-link` reset), not
    # `:strip` -- a fully bare `<button>` falls back to raw browser/OS
    # form-control chrome (shows up as a blue background in some
    # browsers) with nothing in MO's CSS to reset it. `.btn-link`
    # already zeroes background/border/box-shadow.
    #
    # `placement: "bottom"` overrides `CRUDBase`'s own hardcoded
    # `"top"` (deep_merge lets `data:` win) -- the tooltip's the
    # button's job now, not the icon's (see `interest_icon`).
    def interest_button(method, path, kind:, alt_key:, params:)
      Button(type: method, target: path, name: alt_key.l(object: type.l),
             variant: :link, params:, form: { class: "interest-link" },
             data: { turbo_stream: "true", placement: "bottom",
                     tooltip_container: TOOLTIP_CONTAINER }) do
        interest_icon(:small, kind, alt_key)
      end
    end

    # `size` is `:big` (state-indicator icon, no button wrapper -- it
    # needs its own tooltip) or `:small` (clickable variant inside a
    # `Button`, which already supplies an equivalent tooltip via
    # `name:` -- adding a second one on the icon itself doubled up
    # visibly, one above the button and one below). The filename is
    # `<kind>2.png` for big, `<kind>3.png` for small — matches the
    # asset naming pre-conversion.
    #
    # `mo-icon` (see _icons.scss) puts these on the same shared sizing
    # system as every other icon in the app -- `.interest-eyes
    # .mo-icon` (_content.scss) sets the actual 1.5em square, matching
    # #top_nav .top_nav_icon_button .mo-icon's scale, same for the big
    # indicator and the two small buttons alike. `interest_#{kind}`
    # (watch/ignore/halfopen) is a stable hook for tests -- asserting
    # against it instead of the image filename means controller-level
    # tests don't need to change if this ever moves off .png (e.g. to
    # the SVG sprite).
    def interest_icon(size, kind, alt_key)
      alt = alt_key.l(object: type.l)
      suffix = size == :big ? "2" : "3"
      attrs = { src: asset_path("#{kind}#{suffix}.png"),
                alt: alt, class: "mo-icon interest_#{kind}" }
      if size == :big
        attrs[:title] = alt
        attrs[:data] = { tooltip_target: "tip", placement: :bottom,
                         tooltip_container: TOOLTIP_CONTAINER }
      end
      img(**attrs)
    end
  end
end
