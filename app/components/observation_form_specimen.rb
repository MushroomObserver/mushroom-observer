# frozen_string_literal: true

# Specimen section of the observation form.
# Renders specimen checkbox and collapsible collection number/herbarium fields.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param mode [Symbol] :create or :update
# @param collectors_name [String] default collector name
# @param collectors_number [String] default collector number
# @param herbarium_name [String] default herbarium name
# @param herbarium_id [Integer] default herbarium ID
# @param accession_number [String] default accession number
class Components::ObservationFormSpecimen < Components::Base
  prop :form, _Any
  prop :observation, Observation
  prop :mode, _Nilable(Symbol), default: :create
  prop :collectors_name, _Nilable(String), default: nil
  prop :collectors_number, _Nilable(String), default: nil
  prop :herbarium_name, _Nilable(String), default: nil
  prop :herbarium_id, _Nilable(Integer), default: nil
  prop :accession_number, _Nilable(String), default: nil

  def view_template
    div(id: "observation_specimen_section") do
      render_specimen_checkbox
      render_edit_help if update?
      render_specimen_fields if create?
    end
  end

  private

  def render_specimen_checkbox
    @form.checkbox_field(
      :specimen,
      label: :form_observations_specimen_available.l,
      wrap_class: "mt-0",
      help: :form_observations_specimen_available_help.t,
      data: specimen_toggle_data,
      aria: { controls: "specimen_fields", expanded: @observation.specimen }
    )
  end

  def specimen_toggle_data
    { toggle: "collapse", target: "#specimen_fields" }
  end

  def render_edit_help
    help_block_with_arrow(nil) do
      :form_observations_edit_specimens_help.t
    end
  end

  def render_specimen_fields
    div(id: "specimen_fields",
        class: class_names("collapse", ("in" if @observation.specimen))) do
      render_collection_number_fields
      render_herbarium_record_fields
    end
  end

  def render_collection_number_fields
    div(class: "mt-3") do
      @form.namespace(:collection_number) do |cn_ns|
        render_collector_name_field(cn_ns)
        render_collector_number_field(cn_ns)
      end
    end
  end

  def render_collector_name_field(cn_ns)
    help = :form_observations_collection_number_help.t
    render(cn_ns.field(:name).text(
             wrapper_options: { label: "#{:collection_number_name.l}:",
                                help: help },
             value: @collectors_name
           ))
  end

  def render_collector_number_field(cn_ns)
    render(cn_ns.field(:number).text(
             wrapper_options: { label: "#{:collection_number_number.l}:" },
             value: @collectors_number,
             data: { action: "specimen#checkCheckbox" }
           ))
  end

  def render_herbarium_record_fields
    div(class: "mt-3") do
      @form.namespace(:herbarium_record) do |hr_ns|
        render_herbarium_autocompleter(hr_ns)
        render_accession_number(hr_ns)
        render_herbarium_notes(hr_ns)
      end
    end
  end

  def render_herbarium_autocompleter(hr_ns)
    label = "#{:herbarium_record_herbarium_name.l}:"
    help = :form_observations_herbarium_record_help.t
    render(hr_ns.field(:herbarium_name).autocompleter(
             type: :herbarium,
             wrapper_options: { label: label, help: help },
             value: @herbarium_name,
             hidden_value: @herbarium_id,
             create_text: :create_herbarium.l,
             create: "herbarium",
             create_path: new_herbarium_path
           ))
  end

  def render_accession_number(hr_ns)
    label = "#{:herbarium_record_accession_number.l}:"
    render(hr_ns.field(:accession_number).text(
             wrapper_options: { label: label },
             value: @accession_number,
             data: { action: "specimen#checkCheckbox" }
           ))
  end

  def render_herbarium_notes(hr_ns)
    render(hr_ns.field(:notes).text(
             wrapper_options: { label: "#{:herbarium_record_notes.l}:" },
             value: ""
           ))
  end

  def create?
    @mode == :create
  end

  def update?
    @mode == :update
  end
end
