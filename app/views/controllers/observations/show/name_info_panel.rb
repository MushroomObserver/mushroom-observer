# frozen_string_literal: true

# "About this taxon" panel on the observation show page. Collapsed by
# default -- an empty Turbo Frame placeholder -- to keep the page's
# initial load from paying for the name subtree (synonyms, alt
# descriptions, interests) on every view (#5093). Expanding the panel
# sends a real GET to `Observations::NameInfoPanelsController#show`
# carrying a `Turbo-Frame` header, fetching the two-column "On MO" /
# "On the web" content rendered by `Views::Controllers::Observations::
# NameInfoPanels::Show`.
class Views::Controllers::Observations::Show::NameInfoPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  BODY_ID = "observation_name_info_body"

  def view_template
    Panel(panel_id: "observation_name_info", panel_class: "small",
          collapse_target: "##{BODY_ID}", expanded: false) do |panel|
      panel.with_heading { :about_this_taxon.l }
      panel.with_heading_links { render_toggle }
      panel.with_body(collapse: true) { render_frame }
    end
  end

  private

  # Must match `Views::Controllers::Observations::NameInfoPanels::
  # Show#frame_id`.
  def frame_id = "name_info_frame_#{@obs.id}"

  # Bootstrap's collapse.js only calls preventDefault() when
  # `data-target` is absent -- passing `fallback_href:` makes
  # `Link::CollapseToggle` set `data-target` explicitly (see
  # `Components::Panel#collapse_toggle_data`'s comment), so this
  # click's real `href` navigation goes through to Turbo, which
  # intercepts it via `data-turbo-frame` and fetches instead of doing
  # a full-page nav. Not using Panel's own `collapsible:` auto-toggle
  # here since it deliberately skips `data-target` for id-based
  # targets, blocking exactly this fetch.
  def render_toggle
    Link(type: :collapse_toggle,
         target_id: BODY_ID,
         fallback_href: name_info_panel_for_observation_path(@obs.id),
         class: "panel-collapse-trigger ml-3",
         data: { turbo_frame: frame_id }) do
      Icon(type: :chevron_down, title: :open.ti, class: "active-icon")
      Icon(type: :chevron_up, title: :close.ti)
    end
  end

  def render_frame
    turbo_frame_tag(frame_id)
  end
end
