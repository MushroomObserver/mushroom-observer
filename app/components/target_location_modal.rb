# frozen_string_literal: true

# Bootstrap modal that lets a project admin add one of an
# observation's comma-suffixes as a project target_location. Rendered
# on demand (turbo-stream response from
# `Projects::ViolationsController#target_location_modal`) so each
# open sees fresh DB state — needed because admins frequently create
# missing suffix Locations in a separate tab and need the radios to
# pick those up without a page reload (#4304).
#
# When the obs has usable suffixes, the body+footer are owned by
# `Components::TargetLocationForm` via Modal's `:form_content` slot
# (the form spans both — submit in the footer is naturally inside
# the form). When the obs's `where` is just a country (no usable
# suffixes), render a static message body + Cancel-only footer
# instead.
class Components::TargetLocationModal < Components::Base
  prop :project, Project
  prop :obs, Observation
  prop :user, User

  def view_template
    # NOT `auto_open: true`. The modal-toggle Stimulus controller
    # calls `$(_modal).modal('show')` after appending this modal to
    # `body`, so Bootstrap creates its own backdrop. `auto_open: true`
    # would render a SECOND backdrop element here that Bootstrap
    # wouldn't clean up on dismiss — leaving a stuck dark overlay
    # over the page (#4304 regression caught manually).
    render(Components::Modal.new(
             id: modal_id,
             title: :form_violations_modal_target_location_title.l,
             user: @user
           )) do |m|
      if Components::TargetLocationForm.applicable?(@obs)
        m.with_form_content do
          render(Components::TargetLocationForm.new(
                   obs: @obs, project: @project
                 ))
        end
      else
        render_no_suffixes_slots(m)
      end
    end
  end

  def self.modal_id_for(obs)
    "location_target_modal_#{obs.id}"
  end

  private

  def modal_id
    self.class.modal_id_for(@obs)
  end

  def render_no_suffixes_slots(modal)
    modal.with_body do
      p { :form_violations_modal_target_location_no_suffixes.l }
    end
    modal.with_footer do
      button(type: "button", class: "btn btn-default",
             data: { dismiss: "modal" }) { :CANCEL.l }
    end
  end
end
