# frozen_string_literal: true

# Form for creating or editing external links for observations. Rendered
# by `Observations::ExternalLinksController#{new,edit}`, both as an
# inline page form and as the body of the new/edit modal (via
# `Components::Modal::TurboForm`, which auto-resolves this class from
# `controller_path`).
#
# A link is identified by external_id OR url. The `external-link-form` Stimulus
# controller keeps exactly one field active (editable); the other is grayed
# (readonly) but keeps its value, and on submit only the active field is sent.
# The url field is seeded with the selected site's prefix and reset on site
# change.
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
      render_external_id_field
      render_url_field
      render_hidden_fields
      render_site_select
      render_relationship_field if model.persisted?
      submit(submit_text, center: true)
    end

    private

    def render_external_id_field
      text_field(:external_id,
                 size: 40,
                 label: :EXTERNAL_ID.l,
                 wrap_class: "w-100",
                 data: field_data("externalId"))
    end

    def render_url_field
      text_field(:url,
                 size: 40,
                 value: url_seed,
                 label: :URL.l,
                 wrap_class: "w-100",
                 data: field_data("url")) do |f|
        f.with_append { :show_observation_add_link_dialog.l }
      end
    end

    def field_data(target)
      { external_link_form_target: target,
        action: "focus->external-link-form#activate" }
    end

    # Seed: an existing stored url, else the selected site's url prefix (so the
    # user appends the id). observation_url("") yields the template/base prefix.
    def url_seed
      model.url.presence || @site&.observation_url("")
    end

    def render_relationship_field
      select_field(:relationship,
                   ExternalLink.relationships.keys.map { |k| [k.humanize, k] },
                   label: :RELATIONSHIP.l,
                   inline: true,
                   selected: model.relationship)
    end

    def render_hidden_fields
      hidden_field(:user_id, value: @user&.id)
      hidden_field(:observation_id, value: @observation.id)
    end

    def render_site_select
      select_field(:external_site_id,
                   @sites.sort_by(&:name).map { |site| [site.name, site.id] },
                   label: :EXTERNAL_SITE.l,
                   inline: true,
                   selected: (@site || @sites.first)&.id,
                   data: { external_link_form_target: "site",
                           action: "change->external-link-form#siteChanged" })
    end

    def submit_text
      model.persisted? ? :UPDATE.l : :ADD.l
    end

    def form_action
      if model.persisted?
        url_params = { action: :update, id: model.id }
        url_params[:back] = @back if @back.present?
        url_for(controller: "observations/external_links",
                **url_params, only_path: true)
      else
        url_for(controller: "observations/external_links",
                action: :create, id: @observation.id, only_path: true)
      end
    end

    # external_id is active by default; an existing url-only link starts on url.
    def active_field
      model.url.present? && model.external_id.blank? ? "url" : "external_id"
    end

    # site id => url prefix, so the Stimulus controller can seed/reset the url.
    def site_prefixes
      @sites.to_h { |site| [site.id, site.observation_url("")] }
    end

    def around_template
      @attributes[:data] ||= {}
      @attributes[:data][:controller] = "external-link-form"
      @attributes[:data][:external_link_form_active_value] = active_field
      @attributes[:data][:external_link_form_prefixes_value] =
        site_prefixes.to_json
      super
    end
  end
end
