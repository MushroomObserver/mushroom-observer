# frozen_string_literal: true

module Views::Controllers::Projects::Members
  # Turbo-stream modal shown when a project member clicks
  # "Add My Observations" (#4129). Composes Components::Modal
  # directly — the submit is a put_button (button_to mini-form),
  # so there's no wrapping form to coordinate, just a Cancel +
  # Submit button row in `.modal-footer`. Renders nothing in the
  # body when count is zero except the "none match" message.
  class AddObsModal < Views::Base
    def initialize(project:, candidate:, count:, batch_limit:)
      super()
      @project = project
      @candidate = candidate
      @count = count
      @batch_limit = batch_limit
    end

    def view_template
      render(Components::Modal.new(
               id: "modal_add_obs",
               title: :change_member_add_obs.l
             )) do |m|
        m.with_body { p { plain(body_text) } }
        m.with_footer { render_footer_buttons }
      end
    end

    private

    def body_text
      if @count.zero?
        :add_obs_modal_none.l
      elsif @count <= @batch_limit
        :add_obs_modal_all.l(count: @count)
      else
        :add_obs_modal_partial.l(count: @count, limit: @batch_limit)
      end
    end

    def render_footer_buttons
      render(::Components::Button.new(
               name: :CANCEL.l,
               data: { dismiss: "modal" }
             ))
      whitespace
      render_submit_button if @count.positive?
    end

    def render_submit_button
      render(Components::Button.new(
               type: :put,
               name: submit_label,
               target: project_member_path(
                 project_id: @project.id,
                 candidate: @candidate.id,
                 commit: :change_member_add_obs.l,
                 target: :project_index
               ),
               variant: :primary
             ))
    end

    def submit_label
      if @count <= @batch_limit
        :add_obs_modal_add_all.l
      else
        :add_obs_modal_add_next.l(limit: @batch_limit)
      end
    end
  end
end
