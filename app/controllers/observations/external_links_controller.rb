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
      if @sites.empty?
        flash_warning(:permission_denied.t)
        show_flash_and_send_back
        return
      end

      respond_to do |format|
        format.turbo_stream { render_modal_external_link_form }
        format.html { render_new_html }
      end
    end

    def create
      set_ivars_for_new
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
        format.html { render_edit_html }
      end
    end

    def update
      set_ivars_for_edit
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
      @site = @sites&.first
      @back_object = @observation
    end

    def set_ivars_for_edit
      @external_link = ExternalLink.show_includes.find(params[:id].to_s)
      # The link is strict-loaded with a shallow polymorphic target, so load
      # the observation with its own matrix-box subtree for the edit card.
      @observation = Observation.strict_loading.
                     includes(Observation.matrix_box_includes).
                     find(@external_link.observation.id)
      @site = @external_link.external_site
      @sites = ExternalSite.sites_user_can_add_links_to_for_obs(
        @user, @observation, admin: in_admin_mode?
      ).to_a
      @sites |= [@site] # the link's current site must stay selectable
      @back_object = @observation
    end

    def check_external_link_permission!(link: nil, obs: nil, site: nil)
      if link
        obs  = link.observation
        site = link.external_site
      end
      return true if permitted_external_link?(obs, site)

      flash_warning(:permission_denied.t)
      show_flash_and_send_back
      false
    end

    # Compare by id (not the loaded user object): the link's polymorphic
    # target is strict-loaded shallowly, so touching obs.user would lazily
    # load it. user_id is already on the record.
    def permitted_external_link?(obs, site)
      obs&.user_id == @user&.id || site&.member?(@user) || @user.admin
    end

    def create_external_link
      @external_link = ExternalLink.create(
        permitted_external_link_params.merge(
          user: @user, observation: @observation, external_site: @site
        )
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
        format.html { redirect_to(redirect_params) and return true }
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
          redirect_to(permanent_observation_path(@observation))
        end
      end
    end

    def update_external_link
      @external_link.update(permitted_external_link_params)

      if @external_link.errors.any?
        flash_error_and_reload
      else
        flash_success_and_return
      end
    end

    # Editable on update by any editor: url + external_id (mutually exclusive —
    # the model drops url when external_id is present) + relationship.
    def permitted_external_link_params
      params.require(:external_link).permit(:url, :external_id, :relationship)
    end

    def remove_external_link
      @id = @external_link.id
      # Refetch fresh (non-strict_loading) for the destroy cascade.
      ExternalLink.find(@external_link.id).destroy!

      flash_success_and_return
    end

    def show_flash_and_send_back
      # for ExternalLinksControllerTest#test_external_link_permission, which
      # tests check_external_link_permission! directly without sending a request
      return unless @_response

      respond_to do |format|
        # renders the flash in the modal, but not sure it's necessary
        # to have a response here. are they getting sent back?
        format.turbo_stream { render_modal_flash_update(modal_identifier) }
        format.html do
          redirect_to(permanent_observation_path(@observation)) and return
        end
      end
    end

    def render_new_html
      render(Views::Controllers::Observations::ExternalLinks::New.new(
               external_link: @external_link,
               observation: @observation,
               sites: @sites.to_a,
               site: @site,
               user: @user
             ))
    end

    def render_edit_html
      render(Views::Controllers::Observations::ExternalLinks::Edit.new(
               external_link: @external_link,
               observation: @observation,
               site: @site,
               back: @back,
               user: @user
             ))
    end

    def render_modal_external_link_form
      render(Components::Modal.new(
               type: :turbo_form,
               identifier: modal_identifier,
               title: modal_title,
               user: @user,
               model: @external_link,
               observation: @observation,
               back: @back,
               form_locals: { sites: @sites, site: @site }
             ), layout: false)
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
        :add_object.t(type: :external_link)
      when "edit", "update"
        render_to_string(Views::Layouts::Header::ObjectTitle.new(
                           object: @external_link, mode: :edit,
                           title: :external_link.ti
                         ))
      end
    end

    def render_external_links_section_update
      # Refetch with just the external-links subtree the panel +
      # `sites_user_can_add_links_to_for_obs` access — much cheaper
      # than the full `show_includes` tree for a panel re-render.
      @observation = Observation.includes(
        external_links: { external_site: { project: :user_group } }
      ).find(@observation.id)
      @other_sites = ExternalSite.sites_user_can_add_links_to_for_obs(
        @user, @observation, admin: in_admin_mode?
      )
      klass = Views::Controllers::Observations::Show::ExternalLinksPanel
      render_obs_section_update(
        identifier: "external_links",
        panel: klass.new(obs: @observation, user: @user,
                         sites: @other_sites&.to_a, siblings: [])
      ) and return
    end

    # this updates both the form and the flash
    def reload_external_link_modal_form_and_flash
      render_modal_form_reload(identifier: modal_identifier, form_locals: {
                                 user: @user,
                                 model: @external_link,
                                 observation: @observation,
                                 back: @back,
                                 sites: @sites,
                                 site: @site
                               }) and return true
    end
  end
end
