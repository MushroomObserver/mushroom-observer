# frozen_string_literal: true

# inherit_classification
module Names::Classification
  class InheritController < ApplicationController
    before_action :login_required
    before_action :store_location

    # form
    def new
      return unless find_name!
      return unless make_sure_name_is_at_or_above_genus!(@name)

      render_new_view
    end

    # POST callback
    def create
      return unless find_name!
      return unless make_sure_name_is_at_or_above_genus!(@name)

      @parent_text_name = params.dig(:inherit_classification, :parent).
                          to_s.strip_html.strip_squeeze
      parent = resolve_name!(@parent_text_name, chosen_parent_id)
      unless parent && make_sure_parent_has_classification!(parent) &&
             make_sure_parent_higher_rank!(parent)
        render_new_view_invalid and return
      end

      @name.inherit_classification(parent)
      redirect_to(@name.show_link_args)
    end

    private

    # `candidates` is the disambiguation radio alert's pick (ambiguous
    # fuzzy text match); `parent_id` is the clade autocompleter's
    # direct pick. Both resolve to the same `chosen_id` concept in
    # `resolve_name!`, so prefer whichever the submission carries.
    def chosen_parent_id
      params.dig(:inherit_classification, :candidates).presence ||
        params.dig(:inherit_classification, :parent_id)
    end

    def render_new_view(status: :ok, **render_opts)
      render(Views::Controllers::Names::Classification::Inherit::New.new(
               name: @name,
               parent_text_name: @parent_text_name,
               candidates: @candidates,
               message: @message
             ),
             status: status,
             location: form_to_inherit_classification_of_name_path,
             **render_opts)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
