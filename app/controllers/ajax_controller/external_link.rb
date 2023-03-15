# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::ExternalLink
  # Add, edit or remove external link associated with an observation.
  # Returns link id on success.
  def external_link
    @user = session_user!
    case @type
    when "add"
      add_external_link(@id, params[:site].to_s, @value)
    when "edit"
      edit_external_link(@id, @value)
    when "remove"
      remove_external_link(@id)
    end
  end

  private

  def add_external_link(obs_id, site_id, url)
    obs = Observation.find(obs_id)
    site = ExternalSite.find(site_id)
    check_link_permission!(obs, site)
    create_link(obs, site, url)
  end

  def edit_external_link(link_id, url)
    link = ExternalLink.find(link_id)
    check_link_permission!(link)
    update_link(link, url)
  end

  def remove_external_link(link_id)
    link = ExternalLink.find(link_id)
    check_link_permission!(link)
    remove_link(link)
  end

  def check_link_permission!(obs, site = nil)
    if obs.is_a?(ExternalLink)
      link = obs
      obs  = link.observation
      site = link.external_site
    end
    return if obs.user == @user || site.member?(@user) || @user.admin

    raise("Permission denied.")
  end

  def create_link(obs, site, url)
    link = ExternalLink.create(
      user: @user,
      observation: obs,
      external_site: site,
      url: url
    )
    render_errors_or_id(link)
  end

  def update_link(link, url)
    link.update(url: url)
    render_errors_or_id(link)
  end

  def remove_link(link)
    id = link.id
    link.destroy!
    render(plain: id)
  end

  def render_errors_or_id(link)
    if link.errors.any?
      msg = link.formatted_errors.join("\n")
      render(plain: msg.strip_html, status: :internal_server_error)
    else
      render(plain: link.id)
    end
  end
end
