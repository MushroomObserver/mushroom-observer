# frozen_string_literal: true

# Choice modal shown when the edit icon is clicked on a non-primary
# occurrence member (#5317). It explains that the observation is not the
# occurrence's primary (and, if it is a read-only reflection, that it
# can't be edited here), then offers the appropriate edit targets:
#
# - editable non-primary: Edit Primary / Edit This / Cancel
# - reflection with an editable sibling: Edit Primary / Cancel
# - reflection with no editable sibling: Create Editable Primary / Cancel
#
# "Edit Primary" and "Create Editable Primary" hit the same route
# (target=primary); the controller resolves which member to edit.
module Views::Controllers::Observations
  class Show::EditModal < Views::Base
    MODAL_ID = "edit_occurrence_modal"

    prop :observation, ::Observation
    prop :occurrence, _Nilable(::Occurrence), default: nil
    prop :user, _Nilable(::User), default: nil

    def view_template
      Modal(id: MODAL_ID, title: modal_title, user: @user) do |m|
        m.with_body { render_explanation }
        m.with_footer { render_buttons }
      end
    end

    # Title by case: create a match (reflection, no editable sibling);
    # edit the one matching native (a reflection whose sibling is
    # editable -- a single option); or, for an editable non-primary,
    # choose which of two to edit.
    def modal_title
      return :edit_occurrence_create_title.l if create_target?
      return :edit_occurrence_edit_match_title.l if @observation.reflection?

      :edit_occurrence_modal_title.l
    end

    private

    def render_explanation
      # "not primary" only for a non-primary occurrence member -- not for
      # a lone reflection (its occurrence's primary, or with no
      # occurrence yet), where only the read-only line applies (#5328).
      p { :edit_occurrence_not_primary.l } if non_primary_member?
      p { :edit_occurrence_is_reflection.l } if @observation.reflection?
    end

    def non_primary_member?
      @occurrence && @occurrence.primary_observation_id != @observation.id
    end

    def render_buttons
      Button(type: :get, name: primary_button_label,
             target: edit_observation_path(@observation.id, target: :primary),
             variant: :primary)
      whitespace
      render_edit_this
      whitespace
      cancel_button
    end

    # Editing this member directly is offered only for an editable
    # non-primary; a reflection can't be edited here.
    def render_edit_this
      return if @observation.reflection?

      Button(type: :get, name: :edit_occurrence_edit_this.l,
             target: edit_observation_path(@observation.id))
    end

    def cancel_button
      Button(name: :cancel.ti, data: { dismiss: "modal" })
    end

    def primary_button_label
      if create_target?
        :edit_occurrence_create_primary.l
      else
        :edit_occurrence_edit_primary.l
      end
    end

    def create_target?
      @observation.reflection? && !editable_sibling?
    end

    def editable_sibling?
      return false unless @occurrence

      @occurrence.observations.any? do |obs|
        !obs.reflection? && (in_admin_mode? || obs.can_edit?(@user))
      end
    end
  end
end
