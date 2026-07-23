# frozen_string_literal: true

# Compact "Shared with [iNat] [MCP]" badge line -- the replacement
# for the old External-Links list panel (and for the ImportSource
# credit line: an import's own badge modal already shows "Imported
# from iNaturalist (id)", so a separate always-visible credit line is
# redundant). Each badge is an accordion-collapse trigger AND a Turbo
# Frame link to `ExternalLinksController#show` in one -- clicking
# opens (or switches to) that badge's pane directly below the badge
# row, and the pane's empty `turbo-frame` fetches the list of every
# own + sibling `ExternalLink` for that site. Only one pane is ever
# open (native Bootstrap collapse accordion via `data-parent`). Hides
# silently when there's nothing to show and no eligible site to add a
# link to. Rendered as its own top `panel-body` by `Details`, the slot
# ImportSource used to occupy.
class Views::Controllers::Observations::Show::Details::ExternalLinks < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil
  prop :sites, _Nilable(_Array(::ExternalSite)), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  # Hardcoded badge labels, same literal-name-matching pattern already
  # used by `Components::Link::External#inaturalist?` -- "MCP" isn't an
  # actual `ExternalSite.name`, just this component's badge text.
  SITE_BADGES = { "iNaturalist" => "iNat", "MyCoPortal" => "MCP" }.freeze

  def view_template
    return if visible_sites.empty? && !show_new_link?

    div(id: "observation_external_links",
        data: { controller: "section-update",
                section_update_user_value: @user&.id }) do
      div(class: wrapper_class) do
        render_badges
        render_new_link if show_new_link?
      end
      render_accordion
    end
  end

  private

  # Only add the flex/justify-content-between shell when there's a
  # right-side item (the add link) to space against -- an empty right
  # side would otherwise leave a wasted flex wrapper around one item.
  # Kept on its own inner div (not the outer #observation_external_links
  # container) so the accordion pane below it isn't itself a flex item
  # trying to sit beside the badges/add-link row.
  def wrapper_class
    class_names("obs-links",
                show_new_link? && "d-flex justify-content-between")
  end

  def render_badges
    return unless visible_sites.any?

    div do
      plain("#{:shared_with.ti}: ")
      visible_sites.each { |site_name, link| render_badge(site_name, link) }
    end
  end

  def visible_sites
    @visible_sites ||= SITE_BADGES.filter_map do |site_name, _label|
      link = representative_link_for(site_name)
      [site_name, link] if link
    end
  end

  # Case-insensitive: ExternalSite.name has case-insensitive uniqueness
  # (see the model validation), so two sites can never collide on
  # casing alone -- matching case-insensitively here means a stray
  # casing mismatch between SITE_BADGES and the real record can't
  # silently hide a badge again.
  def representative_link_for(site_name)
    all_links.find { |link| link.external_site.name.casecmp?(site_name) }
  end

  def all_links
    @obs.external_links + @siblings.flat_map(&:external_links)
  end

  def render_badge(site_name, link)
    Link(type: :collapse_toggle,
         target_id: "pane_#{link.id}",
         fallback_href: external_link_path(link.id),
         class: "badge badge-id inline-link text-uppercase",
         data: {
           parent: "#external_links_accordion",
           turbo_frame: "external_link_frame_#{link.id}",
           trigger: "tooltip", placement: "bottom",
           title: :show_observation_shared_with_tooltip.l(
             site: site_name
           )
         }) { plain(SITE_BADGES[site_name]) }
    whitespace
  end

  # Accordion panes, one per visible site -- each an empty Turbo Frame
  # populated on first click by the matching badge above. Sits inside
  # the same section-update wrapper as the badges, so a CRUD-triggered
  # re-render resets every pane to closed along with the badge list.
  def render_accordion
    return unless visible_sites.any?

    Accordion(id: "external_links_accordion", class: "m-0") do |accordion|
      visible_sites.map(&:last).each do |link|
        accordion.with_pane(id: "pane_#{link.id}") do
          turbo_frame_tag("external_link_frame_#{link.id}")
        end
      end
    end
  end

  # The badges themselves are informational and shown to everyone;
  # only the add-link affordance needs a logged-in user.
  def show_new_link?
    @user && @sites.present?
  end

  def render_new_link
    InlineCRUDLinks(
      modal_id: "external_link",
      tab: ::Tab::ExternalLink::New.new(observation: @obs)
    )
  end
end
