# frozen_string_literal: true

# Action template for `CollectionNumbersController#show`. Replaces
# `app/views/controllers/collection_numbers/show.html.erb`.
module Views::Controllers::CollectionNumbers
  class Show < Views::Base
    prop :collection_number, ::CollectionNumber
    prop :user, ::User

    def view_template
      add_show_title(@collection_number)
      add_edit_icons(@collection_number, @user)
      add_pager_for(@collection_number)
      column_classes(:six)

      render_details
      render_observation_matrix
      render(Components::Timestamps.new(object: @collection_number))
    end

    private

    def render_details
      render(Components::ContentPadded.new) do
        render_field(:collection_number_name.t, @collection_number.name)
        render_field(:collection_number_number.t, @collection_number.number)
        render_user_field
      end
    end

    def render_field(label, value)
      trusted_html(label)
      plain(": #{value}")
      br
    end

    def render_user_field
      trusted_html(:collection_number_user.t)
      plain(": ")
      render(Components::UserLink.new(user: @collection_number.user))
      br
    end

    def render_observation_matrix
      ul(class: "row list-unstyled mt-3") do
        @collection_number.observations.each do |obs|
          render(Components::MatrixBox.new(
                   user: @user, object: obs, columns: "col-xs-12"
                 ))
        end
      end
    end

  end
end
