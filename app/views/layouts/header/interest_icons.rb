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
    # Bootstrap's default tooltip `container: false` inserts the
    # floating tooltip as the trigger's next DOM sibling -- trapped
    # inside the tight `<li>`/`.btn` wrapper here, it gets clipped and
    # mis-stacked. Anchoring it to the whole `<ul>` instead gives it
    # room (same fix as `ImageFragment::VoteInterface#tooltip_container`).
    TOOLTIP_CONTAINER = ".interest-eyes"

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
      destroy_li("halfopen", :interest_default_help)
      update_li(-1, "ignore", :interest_ignore_help)
    end

    def render_ignoring
      icon_li(:big, "ignore", :interest_ignoring)
      update_li(1, "watch", :interest_watch_help)
      destroy_li("halfopen", :interest_default_help)
    end

    def render_default
      create_li(1, "watch", :interest_watch_help)
      create_li(-1, "ignore", :interest_ignore_help)
    end

    # Inert state indicator, not a control -- `tag: :span` + `.disabled`
    # (not `Button(type: :post/...)`, which are real form-submitting
    # controls) gives it the same `.btn.btn-link` box as the two real
    # buttons beside it, so it doesn't render as a bare, oversized,
    # unpadded image alongside them.
    def icon_li(size, kind, alt_key)
      li do
        Button(tag: :span, variant: :link, class: "disabled") do
          interest_icon(size, kind, alt_key)
        end
      end
    end

    # No existing `Interest` row -- `interests_path` has no `:id`
    # segment, so both `id:` and `state:` ride as form params.
    def create_li(state, kind, alt_key)
      params = { type: @object.class.name, id: @object.id, state: }
      li { interest_button(:post, interests_path, kind:, alt_key:, params:) }
    end

    # An `Interest` row already exists and is flipping to the other
    # non-default state -- `:id` in `interest_path` is the WATCHED
    # OBJECT's id, matching what `InterestsController#update` reads
    # from `params[:id]` (not the `Interest` row's own id).
    def update_li(state, kind, alt_key)
      params = { type: @object.class.name, state: }
      li do
        interest_button(:patch, interest_path(@object.id), kind:, alt_key:,
                                                           params:)
      end
    end

    # Returning to the default (no-opinion) state destroys the
    # `Interest` row outright -- no `state:` param needed, the DELETE
    # verb already says what's happening.
    def destroy_li(kind, alt_key)
      params = { type: @object.class.name }
      li do
        interest_button(:delete, interest_path(@object.id), kind:, alt_key:,
                                                            params:)
      end
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
    def interest_icon(size, kind, alt_key)
      alt = alt_key.l(object: type.l)
      suffix = size == :big ? "2" : "3"
      attrs = { src: asset_path("#{kind}#{suffix}.png"),
                alt: alt, class: "interest_#{size}" }
      if size == :big
        attrs[:title] = alt
        attrs[:data] = { tooltip_target: "tip", placement: :bottom,
                         tooltip_container: TOOLTIP_CONTAINER }
      end
      img(**attrs)
    end
  end
end
