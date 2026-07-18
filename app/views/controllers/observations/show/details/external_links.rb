# frozen_string_literal: true

# Compact "Shared with [iNat] [MCP]" badge line -- the replacement
# for the old External-Links list panel (and for the ImportSource
# credit line: an import's own badge modal already shows "Imported
# from iNaturalist (id)", so a separate always-visible credit line is
# redundant). Each badge is a modal-trigger link to
# `ExternalLinksController#show`, which lists every own + sibling
# `ExternalLink` for that specific site. Hides silently when there's
# nothing to show and no eligible site to add a link to. Rendered as
# its own top `panel-body` by `Details`, the slot ImportSource used
# to occupy.
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

    div(id: "observation_external_links", class: wrapper_class,
        data: { controller: "section-update",
                section_update_user_value: @user&.id }) do
      render_badges
      render_new_link if show_new_link?
    end
  end

  private

  # Only add the flex/justify-content-between shell when there's a
  # right-side item (the add link) to space against -- an empty right
  # side would otherwise leave a wasted flex wrapper around one item.
  def wrapper_class
    class_names("obs-links",
                show_new_link? && "d-flex justify-content-between")
  end

  def render_badges
    return unless visible_sites.any?

    div do
      plain("#{:SHARED_WITH.l}: ")
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
    Button(type: :modal,
           name: SITE_BADGES[site_name],
           target: external_link_path(link.id),
           # `Link::Modal#modal_data` prepends "modal_" itself, so this
           # combines with `Components::Modal`'s `id:` in the controller
           # (`"modal_external_link_#{@external_link.id}"`) -- don't
           # double-prefix here.
           modal_id: "external_link_#{link.id}",
           variant: :strip, class: "badge badge-id inline-link text-uppercase",
           data: { toggle: "tooltip", placement: "bottom",
                   title: :show_observation_shared_with_tooltip.l(
                     site: site_name
                   ) })
    whitespace
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
