# frozen_string_literal: true

# Renders one field-slip's details: project line, observation details
# (date / collector / location / notes / id / id_by / other_codes),
# creator line, and a `Components::Matrix::Box` matrix of every
# observation attached via the field-slip's occurrence. Used by the
# field-slip `Show` action template and by the index page's
# `ObjectRow` (one entry per slip).
#
# The `:prepend` slot is the index-page's per-row heading (an `<h4>`
# with `#{:field_slip_code.l}: <CODE>`); `Show` passes nothing.
module Views::Controllers::FieldSlips
  class FieldSlipPanel < Views::Base
    prop :field_slip, ::FieldSlip
    prop :prepend, _Nilable(String), default: nil

    def view_template
      div(id: "field_slip_#{@field_slip.id}") do
        div(class: "mb-4") do
          trusted_html(@prepend) if @prepend
          render_project_line
          br
          render_observation_details if observation
          br
          render_creator_line if @field_slip.user
        end
        render_observations_section
      end
    end

    private

    def observation
      @field_slip.observation
    end

    def render_project_line
      strong { plain("#{:PROJECT.t}:") }
      whitespace
      if @field_slip.project
        Link(type: :object, object: @field_slip.project)
      else
        plain(:field_slip_no_project.t)
      end
    end

    def render_observation_details
      obs = observation
      render_observation_top_lines(obs)
      strong { plain("#{:NOTES.t}:") }
      render_notes_block
      render_observation_id_lines(obs)
    end

    def render_observation_top_lines(obs)
      labeled(:DATE) { plain(obs.when.to_s) }
      render_collector_line(obs)
      labeled(:LOCATION) { render_location_link(obs) }
    end

    # Omit the line entirely when no collector is recorded (#4211).
    # collector_textile is the column's markup/link form (with the
    # expand-window legacy-notes fallback).
    def render_collector_line(obs)
      return unless obs.collector_textile

      labeled(:COLLECTOR) { trusted_html(obs.collector_textile.tl) }
    end

    def render_observation_id_lines(obs)
      labeled(:ID) { trusted_html(obs.field_slip_name.tl) }
      labeled(:ID_BY) { trusted_html(obs.field_slip_id_by.tl) }
      return if obs.other_codes.to_s.empty?

      labeled(:field_slip_other_codes) { trusted_html(obs.other_codes.tl) }
    end

    # Emits `<strong>LABEL: </strong>` + the block's content + `<br>`.
    def labeled(key)
      strong { plain("#{key.t}: ") }
      yield
      br
    end

    def render_location_link(obs)
      Link(type: :location, where: obs.where,
           location: obs.location, click: true)
    end

    def render_notes_block
      div(class: "ml-5 mb-3") do
        @field_slip.notes_fields.each do |field|
          next if field.value.blank?

          strong { plain("#{field.label}: ") }
          trusted_html(field.value.tl)
          br
        end
      end
    end

    def render_creator_line
      usr = @field_slip.user
      strong { plain("#{:field_slip_creator.t}:") }
      whitespace
      Link(type: :user, user: usr, name: usr.legal_name)
      br
    end

    # Reads `@field_slip.observations` without running a query —
    # the controller eager-loads `occurrence: { observations: [...]}`
    # at lookup time, so this hits the cached collection. New
    # callers of `FieldSlipPanel` must preserve that contract.
    def render_observations_section
      all_obs = @field_slip.observations.to_a
      strong { plain("#{:OBSERVATIONS.t}:") }
      if all_obs.any?
        render_observations_matrix(all_obs)
      else
        whitespace
        plain(:field_slip_no_observation.t)
      end
    end

    def render_observations_matrix(all_obs)
      ul(class: "row list-unstyled mt-3",
         data: { controller: "matrix-table",
                 action: "resize@window->matrix-table#rearrange" }) do
        all_obs.each do |obs_item|
          render(Components::Matrix::Box.new(
                   user: current_user, object: obs_item
                 ))
        end
      end
    end
  end
end
