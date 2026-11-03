# frozen_string_literal: true

# Project autocompleter + inline submit button that GETs the "new
# project-sourced draft" page for a Location or Name. Separate from
# `Views::Controllers::Descriptions::OtherDescriptionsPanel` so it
# has independent test coverage.
#
# Standard AutocompleterField naming: a String field key ("project",
# not a Symbol, which would be model-bound and namespaced under this
# form's "base") gives the visible field "project" and the hidden
# field "project_id". Submitting that hidden id is a confirmed
# choice, read by `initialize_description_source`'s
# `params[:project_id]` -- distinct from the bare `project` param
# `ApplicationController#set_project_ivar` reads elsewhere as a
# suggestion, not a confirmed pick.
class Components::Description::NewDraftForm < Components::ApplicationForm
  # Not named `parent:` -- Superform::Rails::Form's initialize
  # already reserves that keyword for field-nesting context.
  prop :target, _Union(::Location, ::Name)
  # Suggested project to prefill the autocompleter with -- not
  # necessarily the one the main form already committed to (see
  # `project_chosen:`). Typically derived from the ambient query the
  # caller arrived with (e.g. browsing a project-filtered
  # Observations index), not a hard param choice.
  prop :project, _Nilable(::Project), default: nil
  # True when the main form already committed to a project (an
  # explicit `?project_id=` was given, not just a query-derived
  # suggestion). Nothing left to pick, so this renders nothing.
  prop :project_chosen, _Boolean, default: false

  # Declaring new props on a subclass of a class with a hand-written
  # initialize means `super` skips that parent initialize body --
  # Literal re-validates this class's props against what's forwarded
  # to `super`, so `target:`/`project:`/`project_chosen:` are passed
  # through explicitly rather than consumed into ivars only.
  def initialize(target:, project: nil, project_chosen: false, **)
    super(::FormObject::Base.new, target:, project:, project_chosen:, **)
  end

  def view_template
    return unless render?

    super do
      # .flex-bar's align-items-center would vertically center the
      # button against the label+input stack rather than the input
      # row -- align-items-end overrides it, kept alongside .flex-bar
      # so the .autocompleter flex-grow rules still apply.
      div(class: "flex-bar align-items-end gap-2") do
        render_project_field
        submit(:show_description_new_draft_submit.ti,
               variant: :outline, size: :sm)
      end
    end
  end

  # Public so the `new` description views can decide whether to
  # render a separator between this and the main form below it --
  # Phlex calls this unqualified internally regardless of visibility,
  # but an external caller needs it public to check first.
  #
  # Already committed (arrived with a confirmed project, which
  # locked the main form to it) -- nothing left to pick. Otherwise,
  # admins can draft for any project; everyone else needs at least
  # one membership to have anything to pick from.
  def render?
    return false if @project_chosen

    in_admin_mode? || current_user&.projects_member&.any?
  end

  private

  def render_project_field
    autocompleter_field(
      "project", type: autocompleter_type,
                 label: :project.ti,
                 value: @project&.title, hidden_value: @project&.id
    )
  end

  # Admins can draft for any project; everyone else is limited to
  # the projects they belong to.
  def autocompleter_type
    in_admin_mode? ? :project : :user_project
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
