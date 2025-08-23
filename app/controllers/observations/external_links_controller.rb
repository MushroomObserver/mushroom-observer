# frozen_string_literal: true

# Add, edit and remove external links assoc. with obs.
module Observations
  class ExternalLinksController < ApplicationController
    before_action :login_required

    def new
      set_ivars_for_new
      @external_link = ExternalLink.new(
        user: @user,
        observation: @observation
      )
      check_external_link_permission!(obs: @observation)
      respond_to do |format|
        format.turbo_stream { render_modal_external_link_form }
        format.html
      end
    end

    def create
      set_ivars_for_new
      @url = params.dig(:external_link, :url).to_s
      @site = ExternalSite.find(params.dig(:external_link, :external_site_id))
      unless check_external_link_permission!(obs: @observation, site: @site)
        return
      end

      create_external_link
    end

    def edit
      set_ivars_for_edit
      return unless check_external_link_permission!(link: @external_link)

      respond_to do |format|
        format.turbo_stream { render_modal_external_link_form }
        format.html
      end
    end

    def update
      set_ivars_for_edit
      @url = params.dig(:external_link, :url).to_s
      return unless check_external_link_permission!(link: @external_link)

      update_external_link
    end

    def destroy
      set_ivars_for_edit
      return unless check_external_link_permission!(link: @external_link)

      remove_external_link
    end

    private

    def set_ivars_for_new
      @observation = Observation.find(params[:id].to_s)
      @sites = ExternalSite.sites_user_can_add_links_to_for_obs(
        @user, @observation, admin: in_admin_mode?
      )
      @base_urls = {} # used as placeholders in the url field
      @sites.each { |site| @base_urls[site.name] = site.base_url }

      # @site = ExternalSite.find(params.dig(:external_link, :external_site_id))
      @back_object = @observation
    end

    def set_ivars_for_edit
      @external_link = ExternalLink.find(params[:id].to_s)
      @observation = Observation.find(@external_link.observation_id)
      @site = ExternalSite.find(@external_link.external_site_id)
      @back_object = @observation
    end

    def check_external_link_permission!(link: nil, obs: nil, site: nil)
      if link
        obs  = link.observation
        site = link.external_site
      end
      return true if obs&.user == @user || site&.member?(@user) || @user.admin

      flash_warning(:permission_denied.t)
      show_flash_and_send_back
      false
    end

    def create_external_link
      @external_link = ExternalLink.create(
        user: @user,
        observation: @observation,
        external_site: @site,
        url: @url
      )

      if @external_link.errors.any?
        flash_error_and_reload
      else
        flash_success_and_return
      end
    end

    def flash_error_and_reload
      redirect_params = case action_name # this is a rails var
                        when "create"
                          { action: :new }
                        when "update"
                          { action: :edit }
                        end
      redirect_params = redirect_params.merge({ back: @back }) if @back.present?

      flash_error(@external_link.formatted_errors.join("\n").strip_html)
      respond_to do |format|
        format.turbo_stream { reload_external_link_modal_form_and_flash }
        format.html { redirect_with_query(redirect_params) and return true }
      end
    end

    def flash_success_and_return
      message = case action_name # this is a rails var
                when "create"
                  :runtime_added_to.t(type: :external_link, name: :observation)
                when "update"
                  :runtime_updated_at.t(type: :external_link)
                when "destroy"
                  :runtime_destroyed_id.t(type: :external_link, value: @id)
                end
      flash_notice(message)
      respond_to do |format|
        format.turbo_stream { render_external_links_section_update }
        format.html do
          redirect_with_query(permanent_observation_path(@observation))
        end
      end
    end

    def update_external_link
      @external_link.update(url: @url)

      if @external_link.errors.any?
        flash_error_and_reload
      else
        flash_success_and_return
      end
    end

    def remove_external_link
      @id = @external_link.id
      @external_link.destroy!

      flash_success_and_return
    end

    def show_flash_and_send_back
      # for ExternalLinksControllerTest#test_external_link_permission, which
      # tests check_external_link_permission! directly without sending a request
      return unless @_response

      respond_to do |format|
        # renders the flash in the modal, but not sure it's necessary
        # to have a response here. are they getting sent back?
        format.turbo_stream { render_modal_flash_update }
        format.html do
          redirect_with_query(permanent_observation_path(@observation)) and
            return
        end
      end
    end

    def render_modal_external_link_form
      render(
        partial: "shared/modal_form",
        locals: { title: modal_title, identifier: modal_identifier,
                  user: @user, form: "observations/external_links/form" }
      ) and return
    end

    def modal_identifier
      case action_name
      when "new", "create"
        "external_link"
      when "edit", "update"
        "external_link_#{@external_link.id}"
      end
    end

    def modal_title
      case action_name
      when "new", "create"
        helpers.new_page_title(:add_object, :EXTERNAL_LINK)
      when "edit", "update"
        helpers.edit_page_title(:EXTERNAL_LINK.l, @external_link)
      end
    end

    def render_external_links_section_update
      # need to reset this in case they can now add sites
      @observation = @observation.reload
      @other_sites = ExternalSite.sites_user_can_add_links_to_for_obs(
        @user, @observation, admin: in_admin_mode?
      )
      render(
        partial: "observations/show/section_update",
        locals: { identifier: "external_links",
                  obs: @observation, user: @user, sites: @other_sites }
      ) and return
    end

    def render_modal_flash_update
      render(partial: "shared/modal_flash_update",
             locals: { identifier: modal_identifier }) and return
    end

    # this updates both the form and the flash
    def reload_external_link_modal_form_and_flash
      render(
        partial: "shared/modal_form_reload",
        locals: { identifier: modal_identifier,
                  form: "observations/external_links/form" }
      ) and return true
    end
  end
end
