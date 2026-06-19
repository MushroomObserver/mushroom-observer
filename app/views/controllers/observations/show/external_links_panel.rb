# frozen_string_literal: true

# External-links sub-panel — list of the obs's external-site
# links + sibling-obs external links (read-only) when present.
# Header has a `[ new ]` modal link when there are any
# eligible sites the obs doesn't already have a link to.
class Views::Controllers::Observations::Show::ExternalLinksPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil
  prop :sites, _Nilable(_Array(::ExternalSite)), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    div(
      id: "observation_external_links",
      class: "obs-links",
      data: { controller: "section-update",
              section_update_user_value: @user&.id }
    ) do
      render_header
      render_list if list_visible?
    end
  end

  private

  def render_header
    div do
      plain("#{:EXTERNAL_LINKS.l}: ")
      render_new_link if @sites.present?
    end
  end

  def render_new_link
    render(Components::Link::InlineAdd.new(
             modal_id: "external_link",
             tab: ::Tab::ExternalLink::New.new(observation: @obs)
           ))
  end

  def list_visible?
    @obs.external_links.any? ||
      @siblings.any? { |s| s.external_links.any? }
  end

  def render_list
    ul(class: "tight-list") do
      own_external_links.each { |link| render_own_row(link) }
      sibling_external_links.each do |link, sib|
        render_sibling_row(link, sib)
      end
    end
  end

  def sibling_external_links
    @siblings.flat_map do |sib|
      sib.external_links.map { |el| [el, sib] }
    end
  end

  def render_sibling_row(link, sibling)
    li do
      a(href: link.url, target: "_blank", rel: "noopener") do
        plain(sibling_link_text(link))
      end
      plain(" ")
      sibling_attribution(sibling)
    end
  end

  def sibling_link_text(link)
    if link.external_site.name == "iNaturalist"
      "iNat #{link.url.sub(link.external_site.base_url, "")}"
    else
      link.site_name
    end
  end

  def sibling_attribution(sibling)
    small(class: "text-muted") do
      plain("(")
      a(href: permanent_observation_path(sibling.id)) do
        plain("MO #{sibling.id}")
      end
      plain(")")
    end
  end

  def own_external_links
    @obs.external_links.sort_by(&:site_name)
  end

  def render_own_row(link)
    li(id: "external_link_#{link.id}") do
      render_external_link(link)
      if link.can_edit?(@user) || in_admin_mode?
        render(Components::Link::InlineMod.new(
                 target: link, observation: @obs, user: @user
               ))
      end
    end
  end

  def render_external_link(link)
    a(href: link.url, target: "_blank", rel: "noopener") do
      plain(link.site_name)
    end
  end
end
