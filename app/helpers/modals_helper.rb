# frozen_string_literal: true

# Helper methods for modal dialogs and forms
module ModalsHelper
  # Map model classes to their corresponding component classes
  COMPONENT_MAP = {
    Comment: Components::CommentForm,
    ExternalLink: Components::ExternalLinkForm,
    Herbarium: Components::HerbariumForm,
    HerbariumRecord: Components::HerbariumRecordForm,
    CollectionNumber: Components::CollectionNumberForm,
    MergeRequest: Components::MergeRequestEmailForm,
    NameChangeRequest: Components::NameChangeRequestForm,
    ProjectAlias: Components::ProjectAliasForm,
    Sequence: Components::SequenceForm,
    Naming: Components::NamingForm,
    WebmasterQuestion: Components::WebmasterQuestionForm,
    ObserverQuestion: Components::ObserverQuestionForm,
    CommercialInquiry: Components::CommercialInquiryForm,
    UserQuestion: Components::UserQuestionForm
  }.freeze

  # Renders either a Superform component or a legacy ERB partial for modal
  # forms. This allows gradual migration from ERB partials to Superform.
  #
  # @param form [String] The form path (e.g., "collection_numbers/form")
  # @param model [ActiveRecord::Base, nil] The model instance for the form
  # @param observation [Observation] Optional observation instance
  # @param back [String] Optional back parameter
  # @param form_locals [Hash] Locals to pass to the form
  # @return [String] Rendered HTML
  def render_form_or_component(form, model: nil, observation: nil, back: nil,
                               **form_locals)
    model_key = model ? model.class.name.demodulize.to_sym : nil
    component_class = model_key ? COMPONENT_MAP[model_key] : nil

    if component_class
      render_modal_component(component_class, model, observation, back,
                             form_locals)
    else
      render(partial: form, locals: form_locals)
    end
  end

  private

  def render_modal_component(component_class, model, observation, back, locals)
    params = { local: false } # Modal forms use turbo
    params[:observation] = observation if observation
    params[:back] = back if back
    params.merge!(locals.except(:model, :local))

    render(component_class.new(model, **params))
  end
end
