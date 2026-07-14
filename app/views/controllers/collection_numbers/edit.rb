# frozen_string_literal: true

# Action template for `CollectionNumbersController#edit`. Wraps
# the existing `Form` Phlex component with the page chrome + a
# side-column list of MatrixBox previews (one per associated obs).
module Views::Controllers::CollectionNumbers
  class Edit < Views::FullPageBase
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

      Row do
        Column(xs: 12, sm: 7) { render_form }
        Column(xs: 12, sm: 5) { render_observation_boxes }
      end
    end

    private

    def render_form
      render(Form.new(@collection_number, back: @back))
    end

    def render_observation_boxes
      Row(element: :ul, class: "list-unstyled") do
        @collection_number.observations.each do |obs|
          render(Components::Matrix::Box.new(
                   user: @user,
                   object: obs.rss_log || obs,
                   columns: Components::Column.classes_for(xs: 12)
                 ))
        end
      end
    end
  end
end
