# frozen_string_literal: true

#  edit_classification::
module Names
  class ClassificationController < ApplicationController
    before_action :login_required
    before_action :store_location

    # Form
    def edit
      return unless find_name!

      render_edit_view
    end

    # PUT callback
    def update
      return unless find_name!

      @name.classification =
        params.dig(:name, :classification).to_s.strip_html.strip_squeeze
      return render_edit_view_invalid unless validate_classification!

      @name.change_classification(@name.classification)
      redirect_to(@name.show_link_args)
    end

    private

    def render_edit_view(status: :ok, **render_opts)
      render(Views::Controllers::Names::Classification::Edit.new(
               name: @name
             ),
             status: status,
             location: edit_classification_of_name_path(@name),
             **render_opts)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
