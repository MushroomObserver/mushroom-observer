# frozen_string_literal: true

#  edit_classification::
module Names
  class ClassificationController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # Form
    def edit
      store_location
      nil unless find_name!
    end

    # PUT callback
    def update
      store_location
      return unless find_name!

      @name.classification = params[:classification].to_s.strip_html.
                             strip_squeeze
      return render_edit unless validate_classification!

      @name.change_classification(@name.classification)
      redirect_to(@name.show_link_args)
    end

    private

    def render_edit
      render(:edit, location: edit_classification_of_name_path(@name))
    end

    include Names::Classification::SharedPrivateMethods
  end
end
