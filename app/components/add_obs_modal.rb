# frozen_string_literal: true

# Turbo modal shown when a project member clicks "Add My Observations".
# Displays how many of the member's observations match the project's
# constraints and are not already in the project, with a button that
# submits a PUT to add the next batch (capped at `batch_limit`).
# See issue #4129.
class Components::AddObsModal < Components::Base
  MODAL_ID = "modal_add_obs"

  prop :project, Project
  prop :candidate, User
  prop :count, Integer
  prop :batch_limit, Integer

  def view_template
    div(id: MODAL_ID, class: "modal", role: "dialog",
        aria: { labelledby: "#{MODAL_ID}_title" },
        data: { controller: "modal" }) do
      div(class: "modal-dialog", role: "document") do
        div(class: "modal-content") do
          render_header
          render_body
          render_footer
        end
      end
    end
  end

  private

  def render_header
    div(class: "modal-header") do
      close_button
      h4(class: "modal-title", id: "#{MODAL_ID}_title") do
        plain(:change_member_add_obs.l)
      end
    end
  end

  def close_button
    button(type: :button, class: "close",
           data: { dismiss: "modal" },
           aria: { label: :CLOSE.l }) do
      span(aria: { hidden: "true" }) { "×" }
    end
  end

  def render_body
    div(class: "modal-body") do
      p { plain(body_text) }
    end
  end

  def body_text
    if @count.zero?
      :add_obs_modal_none.l
    elsif @count <= @batch_limit
      :add_obs_modal_all.l(count: @count)
    else
      :add_obs_modal_partial.l(count: @count, limit: @batch_limit)
    end
  end

  def render_footer
    div(class: "modal-footer") do
      render_cancel_button
      whitespace
      render_submit_button if @count.positive?
    end
  end

  def render_cancel_button
    button(type: :button, class: "btn btn-default",
           data: { dismiss: "modal" }) do
      plain(:CANCEL.l)
    end
  end

  def render_submit_button
    put_button(
      name: submit_label,
      class: "btn btn-primary",
      path: project_member_path(
        project_id: @project.id,
        candidate: @candidate.id,
        commit: :change_member_add_obs.l,
        target: :project_index
      )
    )
  end

  def submit_label
    if @count <= @batch_limit
      :add_obs_modal_add_all.l
    else
      :add_obs_modal_add_next.l(limit: @batch_limit)
    end
  end
end
