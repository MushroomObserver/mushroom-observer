# frozen_string_literal: true

module Views::Controllers::Sequences
  # Sequence-edit page.
  class Edit < Views::FullPageBase
    prop :sequence, ::Sequence
    prop :back, _Nilable(::String), default: nil
    prop :back_object, _Nilable(
      _Union(::Observation, ::Sequence)
    ), default: nil

    def view_template
      container_class(:wide)
      add_edit_title(@sequence)
      add_context_nav(::Tab::Sequence::Form.new(back_object: @back_object))

      obs = @sequence.observation
      div(class: "row") do
        div(class: "col-xs-12 col-sm-7") { render_form_column(obs) }
        div(class: "col-xs-12 col-sm-5") { render_matrix_column(obs) }
      end
    end

    private

    def render_form_column(obs)
      render(ObservationTitle.new(observation: obs))
      render(Form.new(@sequence, back: @back))
      div(class: "small") do
        span(class: "font-weight-bold") { "#{:CREATED_BY.l}:" }
        plain(" ")
        render(::Components::Link::Object::User.new(user: @sequence.user))
      end
      render(::Views::Layouts::ObjectFooter.new(
               user: current_user, obj: @sequence
             ))
    end

    def render_matrix_column(obs)
      ul(class: "row list-unstyled") do
        render(::Components::Matrix::Box.new(
                 user: current_user,
                 object: obs.rss_log || obs,
                 columns: "col-xs-12"
               ))
      end
    end
  end
end
