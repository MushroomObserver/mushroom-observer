# frozen_string_literal: true

# Form for creating a new iNat import.
# Renders username, observation IDs, consent, and details.
class Components::InatImportNewForm < Components::ApplicationForm
  def view_template
    text_field(:inat_username,
               label: "#{:inat_username.l}: ", size: 10)
    render_choose_observations_panel
    checkbox_field(:consent,
                   label: :inat_import_consent.l,
                   wrap_class: "mt-3")
    render_details_panel
    submit(:SUBMIT.l)
  end

  def form_action
    inat_imports_path
  end

  private

  def render_choose_observations_panel
    render(Components::Panel.new(
             panel_id: "choose_observation",
             panel_class: "name-section"
           )) do |panel|
      panel.with_heading do
        plain(:inat_choose_observations.l)
      end
      panel.with_body do
        render_observation_fields
      end
    end
  end

  def render_observation_fields
    textarea_field(:inat_ids,
                   label: "#{:inat_import_list.l}: ")
    checkbox_field(:all,
                   label: :inat_import_all.l,
                   wrap_class: "mt-3")
  end

  def render_details_panel
    render(Components::Panel.new) do |panel|
      panel.with_body do
        p do
          b { plain(:inat_details_heading.l) }
        end
        trusted_html(:inat_details_list.t)
      end
    end
  end
end
