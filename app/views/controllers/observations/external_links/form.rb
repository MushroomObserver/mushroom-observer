# frozen_string_literal: true

# Form for creating or editing external links for observations. Rendered
# by `Observations::ExternalLinksController#{new,edit}`, both as an
# inline page form and as the body of the new/edit modal (via
# `Components::Modal::TurboForm`, which auto-resolves this class from
# `controller_path`).
#
# One field: a person pastes either a bare site id or a url copied from
# the external site. `ExternalLink#resolve_submitted_external_id`
# (before_validation) resolves a url to its bare id server-side, or
# rejects it if it doesn't match a resolvable shape -- there's no url
# column to fall back to storing it in.
module Views::Controllers::Observations::ExternalLinks
  class Form < ::Components::ApplicationForm
    prop :observation, ::Observation
    prop :sites, _Array(::ExternalSite)
    prop :site, _Nilable(::ExternalSite), default: nil
    prop :user, ::User
    prop :back, _Nilable(String), default: nil

    # rubocop:disable-next Metrics/ParameterLists
    def initialize(model, observation:, sites:, user:, site: nil,
                   back: nil, **attrs)
      super(model, observation: observation, sites: sites,
                   site: site || sites&.first, user: user, back: back,
                   **attrs)
    end

    def view_template
      render_external_id_field
      render_hidden_fields
      render_site_select
      render_relationship_field if model.persisted?
      submit(submit_text, center: true)
    end

    private

    def render_external_id_field
      text_field(:external_id,
                 size: 40,
                 label: :external_id.ti,
                 wrap_class: "w-100") do |f|
        f.with_append { :show_observation_add_link_dialog.l }
      end
    end

    def render_relationship_field
      select_field(:relationship,
                   ExternalLink.relationships.keys.map { |k| [k.humanize, k] },
                   label: :relationship.ti,
                   inline: true,
                   selected: model.relationship)
    end

    def render_hidden_fields
      hidden_field(:user_id, value: @user.id)
      hidden_field(:observation_id, value: @observation.id)
    end

    def render_site_select
      select_field(:external_site_id,
                   @sites.sort_by(&:name).map { |site| [site.name, site.id] },
                   label: :external_site.ti,
                   inline: true,
                   selected: (@site || @sites.first)&.id)
    end

    def submit_text
      model.persisted? ? :update.ti : :add.ti
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
  end
end
