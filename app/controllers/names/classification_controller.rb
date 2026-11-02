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

      @name.classification = assembled_classification
      return render_edit_view_invalid unless validate_classification!

      @name.change_classification(@name.classification)
      redirect_to(@name.show_link_args)
    end

    private

    # Joins the per-rank fields the form submits into the "Rank:
    # Name" lines validate_classification! parses -- underscores
    # (for textile italics) are added by that reformat step, not
    # here.
    def assembled_classification
      permitted = params.permit(name_classification: rank_param_keys).
                  fetch(:name_classification, {})
      FormObject::NameClassification::RANKS.filter_map do |rank|
        value = permitted[:"rank_#{rank.downcase}"].to_s.strip
        "#{rank}: #{value}" if value.present?
      end.join("\r\n")
    end

    def rank_param_keys
      FormObject::NameClassification::RANKS.map { |rank| :"rank_#{rank.downcase}" }
    end

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
