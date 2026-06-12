# frozen_string_literal: true

# Form for creating or editing external links for observations. Rendered
# by `Observations::ExternalLinksController#{new,edit}`, both as an
# inline page form and as the body of the new/edit modal (via
# `Components::ModalTurboForm`, which auto-resolves this class from
# `controller_path`).
module Views::Controllers::Observations::ExternalLinks
  class Form < ::Components::ApplicationForm
    def initialize(model, **kwargs)
      @observation = kwargs.delete(:observation)
      @sites = kwargs.delete(:sites)
      @site = kwargs.delete(:site) || @sites&.first
      @user = kwargs.delete(:user)
      @back = kwargs.delete(:back)
      super
    end

    def view_template
      render_url_field
      render_hidden_fields
      render_site_select
      submit(submit_text, center: true)
    end

    private

    def render_url_field
      selected_site = @site || @sites&.first
      text_field(:url,
                 size: 40,
                 placeholder: selected_site.base_url,
                 label: :URL.l,
                 between: :required,
                 wrap_class: "w-100",
                 data: { placeholder_target: "textField" }) do |f|
        f.with_append { :show_observation_add_link_dialog.l }
      end
    end

    def render_hidden_fields
      hidden_field(:user_id, value: @user&.id)
      hidden_field(:observation_id, value: @observation.id)
    end

    def render_site_select
      selected_site = @site || @sites&.first
      options = if model.persisted?
                  [@site.name]
                else
                  @sites.sort_by(&:name).map { |site| [site.name, site.id] }
                end

      select_field(:external_site_id, options,
                   label: :EXTERNAL_SITE.l,
                   inline: true,
                   selected: selected_site.id,
                   data: {
                     placeholder_target: "select",
                     action: "placeholder#update",
                     placeholder_text: selected_site.base_url
                   })
    end

    def base_urls
      @base_urls ||= @sites.to_h do |site|
        [site.name, site.base_url]
      end
    end

    def submit_text
      model.persisted? ? :UPDATE.l : :ADD.l
    end

    def form_action
      if model.persisted?
        url_params = { action: :update, id: model.id }
        url_params[:back] = @back if @back.present?
        url_for(
          controller: "observations/external_links",
          **url_params,
          only_path: true
        )
      else
        url_for(
          controller: "observations/external_links",
          action: :create,
          id: @observation.id,
          only_path: true
        )
      end
    end

    def around_template
      # Add stimulus controller for placeholder behavior
      @attributes[:data] ||= {}
      @attributes[:data][:controller] = "placeholder"
      @attributes[:data][:placeholders] = base_urls.to_json
      super
    end
  end
end
