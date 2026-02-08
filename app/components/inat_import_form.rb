# frozen_string_literal: true

# Form for importing iNaturalist observations.
# Collects iNat username, observation IDs or "import all",
# and user consent before requesting iNat authorization.
class Components::InatImportForm < Components::ApplicationForm
  def view_template
    render_username_field
    render_choose_observation_panel
    render_consent_checkbox
    render_details_panel
    submit(:SUBMIT.l)
  end

  private

  def render_username_field
    text_field(:inat_username,
               label: "#{:inat_username.l}: ",
               size: 10)
  end

  def render_choose_observation_panel
    render(choose_observation_panel) do |panel|
      panel.with_heading { :inat_choose_observations.l }
      panel.with_body do
        render_inat_ids_field
        render_import_all_checkbox
      end
    end
  end

  def choose_observation_panel
    Components::Panel.new(
      panel_id: "choose_observation",
      panel_class: "name-section"
    )
  end

  def render_inat_ids_field
    textarea_field(:inat_ids,
                   label: "#{:inat_import_list.l}: ")
  end

  def render_import_all_checkbox
    checkbox_field(:import_all,
                   label: :inat_import_all.l,
                   wrap_class: "mt-3")
  end

  def render_consent_checkbox
    checkbox_field(:consent,
                   label: :inat_import_consent.l,
                   wrap_class: "mt-3")
  end

  def render_details_panel
    render(Components::Panel.new) do |panel|
      panel.with_body do
        p { b { :inat_details_heading.l } }
        trusted_html(:inat_details_list.t)
      end
    end
  end

  def form_action
    url_for(
      controller: "inat_imports",
      action: :create,
      only_path: true
    )
  end
end
