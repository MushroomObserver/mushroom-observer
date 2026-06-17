# frozen_string_literal: true

# Action template for `CollectionNumbersController#edit`. Replaces
# `app/views/controllers/collection_numbers/edit.html.erb`. Wraps
# the existing `Form` Phlex component with the page chrome + a
# side-column list of MatrixBox previews (one per associated obs).
module Views::Controllers::CollectionNumbers
  class Edit < Views::Base
    prop :collection_number, ::CollectionNumber
    prop :user, ::User
    prop :back, _Nilable(String), default: nil
    prop :back_object, _Nilable(::AbstractModel), default: nil

    def view_template
      container_class(:full)
      add_edit_title(@collection_number)
      add_context_nav(
        Tab::CollectionNumber::FormEdit.new(
          collection_number: @collection_number,
          back: @back, back_object: @back_object,
          q_param: q_param
        )
      )

      div(class: "row") do
        div(class: "col-xs-12 col-sm-7") { render_form }
        div(class: "col-xs-12 col-sm-5") { render_observation_boxes }
      end
    end

    private

    def render_form
      render(Form.new(@collection_number, back: @back))
    end

    def render_observation_boxes
      ul(class: "row list-unstyled") do
        @collection_number.observations.each do |obs|
          render(Components::Matrix::Box.new(
                   user: @user,
                   object: obs.rss_log || obs,
                   columns: "col-xs-12"
                 ))
        end
      end
    end
  end
end
