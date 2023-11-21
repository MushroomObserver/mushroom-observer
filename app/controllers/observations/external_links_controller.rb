# frozen_string_literal: true

# Add, edit and remove external links assoc. with obs.
module Observations
  class ExternalLinksController < ApplicationController
    before_action :login_required

    def new
      set_ivars_for_new
      check_link_permission!(@observation, @site)
      render_modal_external_link_form(
        title: :show_observation_add_link.t(site: "MycoPortal")
      )
    end

    def create
      url = params.dig(:external_link, :url).to_s

      set_ivars_for_new
      check_link_permission!(@observation, @site)
      create_link(@observation, @site, url)
    end

    def edit
      set_ivars_for_edit
      check_link_permission!(@external_link)
      render_modal_external_link_form(
        title: :edit_object.t(type: :external_link)
      )
    end

    def update
      url = params.dig(:external_link, :url).to_s

      set_ivars_for_edit
      check_link_permission!(@external_link)
      update_link(@external_link, url)
    end

    def destroy
      set_ivars_for_edit
      check_link_permission!(@external_link)
      remove_link(@external_link)
    end

    private

    def set_ivars_for_new
      @observation = Observation.find(params[:id].to_s)
      @site = ExternalSite.find(params[:external_site_id].to_s)
    end

    def set_ivars_for_edit
      @external_link = ExternalLink.find(params[:id].to_s)
      @observation = Observation.find(@external_link.observation_id)
      @site = ExternalSite.find(@external_link.external_site_id)
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

      if link.errors.any?
        flash_error(link.formatted_errors.join("\n").strip_html)
        reload_external_link_modal_form_and_flash
      else
        flash_notice(
          :runtime_added_to.t(type: :external_link, name: :observation)
        )
        render_external_links_section_update
      end
    end

    def update_link(link, url)
      link.update(url: url)

      if link.errors.any?
        flash_error(link.formatted_errors.join("\n").strip_html)
        reload_external_link_modal_form_and_flash
      else
        flash_notice(:runtime_updated_at.t(type: :external_link))
        render_external_links_section_update
      end
    end

    def remove_link(link)
      id = link.id
      link.destroy!

      flash_notice(:runtime_destroyed_id.t(type: :external_link, value: id))
      render_external_links_section_update
    end

    def render_modal_external_link_form(title:)
      render(
        partial: "shared/modal_form",
        locals: { title: title, identifier: "external_link",
                  form: "observations/external_links/form" }
      ) and return
    end

    def render_external_links_section_update
      # need to reset this in case they can now add sites
      @other_sites = helpers.external_sites_user_can_add_links_to(@observation)
      render(
        partial: "observations/show/section_update",
        locals: { identifier: "external_links" }
      ) and return
    end

    # this updates both the form and the flash
    def reload_external_link_modal_form_and_flash
      render(
        partial: "shared/modal_form_reload",
        locals: { identifier: "external_link",
                  form: "observations/external_links/form" }
      ) and return true
    end
  end
end
