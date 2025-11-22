# frozen_string_literal: true

# Form for creating or editing external links for observations
class Components::ExternalLinkForm < Components::ApplicationForm
  def initialize(model, observation:, sites:, site:, base_urls:, user:,
                 back: nil, **)
    @observation = observation
    @sites = sites
    @site = site
    @base_urls = base_urls
    @user = user
    @back = back
    super(model, **)
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
    render(
      field(:url).text(
        size: 40,
        placeholder: selected_site.base_url,
        wrapper_options: {
          label: :URL.l,
          between: :required,
          wrap_class: "w-100",
          append: :show_observation_add_link_dialog.l
        },
        data: { placeholder_target: "textField" }
      )
    )
  end

  def render_hidden_fields
    input(type: "hidden", name: "external_link[user_id]", value: @user&.id)
    input(
      type: "hidden",
      name: "external_link[observation_id]",
      value: @observation.id
    )
  end

  def render_site_select
    selected_site = @site || @sites&.first
    options = if model.persisted?
                [@site.name]
              else
                @sites.sort_by(&:name).map { |site| [site.name, site.id] }
              end

    render(
      field(:external_site_id).select(
        options,
        wrapper_options: {
          label: :EXTERNAL_SITE.l,
          inline: true
        },
        selected: selected_site.id,
        data: {
          placeholder_target: "select",
          action: "placeholder#update",
          placeholder_text: selected_site.base_url
        }
      )
    )
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
    @attributes[:data][:placeholders] = @base_urls.to_json
    super
  end
end
