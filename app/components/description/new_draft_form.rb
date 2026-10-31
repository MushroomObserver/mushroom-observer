# frozen_string_literal: true

# Project autocompleter + inline submit button that GETs the "new
# project-sourced draft" page for a Location or Name. Separate from
# `Views::Controllers::Descriptions::OtherDescriptionsPanel` so it
# has independent test coverage.
#
# Hand-built flex row, label included, same shape as the top-nav
# search bar and the identify filter (`Observations::Identify::Form`)
# -- not an input-group addon (the autocompleter's `append` slot
# renders below the field, built for a map section), and not
# Bootstrap's `.form-inline` either: that class only un-stacks a
# `.form-group`'s label/input when the form-group is a normal
# block-flow child of the form, and a flex row's `.flex-bar`
# (`display: flex`) turns the form-group into a flex item instead,
# which overrides that cascade -- confirmed live (label stayed
# stacked above the input, submit button pushed to the far end by
# `.flex-bar`'s `justify-content: space-between`).
#
# The autocompleter's hidden field is explicitly keyed "project"
# (bare, no model namespace) to match
# `Locations::DescriptionsController#new` /
# `Names::DescriptionsController#new`'s existing flat
# `params[:project]` read
# (`initialize_description_source`, `app/controllers/concerns/descriptions.rb`)
# -- no controller-side change needed.
class Components::Description::NewDraftForm < Components::ApplicationForm
  # Not named `parent:` -- Superform::Rails::Form's initialize
  # already reserves that keyword for field-nesting context.
  prop :target, _Union(::Location, ::Name)
  prop :project, _Nilable(::Project), default: nil

  # Declaring new props on a subclass of a class with a hand-written
  # initialize means `super` skips that parent initialize body --
  # Literal re-validates this class's props against what's forwarded
  # to `super`, so `target:`/`project:` are passed through
  # explicitly rather than consumed into ivars only.
  def initialize(target:, project: nil, **)
    super(::FormObject::Base.new, target:, project:, **)
  end

  def view_template
    super do
      div(class: "flex-bar gap-2") do
        render_label
        render_project_field
        submit(:create.ti, variant: :outline, size: :sm)
      end
    end
  end

  private

  def render_label
    label(for: project_field_id, class: "mb-0 text-nowrap") do
      plain(append_colon(:show_description_new_draft_label.l))
    end
  end

  def project_field_id
    "project_display"
  end

  def render_project_field
    autocompleter_field(
      project_field_id, type: :user_project, label: false,
                        value: @project&.title,
                        hidden_name: "project", hidden_value: @project&.id
    )
  end

  def form_action
    if @target.is_a?(::Location)
      new_location_description_path(location_id: @target.id)
    else
      new_name_description_path(name_id: @target.id)
    end
  end

  # rubocop:disable-next MO/NoHandRolledFormTag
  def form_tag(&block)
    form(action: form_action, method: :get, **form_attributes, &block)
  end

  def form_attributes
    {
      id: @attributes[:id],
      class: class_names("mb-0", @attributes[:class]),
      data: @attributes[:data] || {}
    }
  end

  # GET forms don't need authenticity tokens or _method fields
  def authenticity_token_field; end
  def _method_field; end
end
