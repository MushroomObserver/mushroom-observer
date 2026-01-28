# frozen_string_literal: true

# inherit_classification
module Names::Classification
  class InheritController < ApplicationController
    before_action :login_required
    before_action :store_location

    # form
    def new
      return unless find_name!

      nil unless make_sure_name_is_at_or_above_genus!(@name)
    end

    # POST callback
    def create
      return unless find_name!
      return unless make_sure_name_is_at_or_above_genus!(@name)

      @parent_text_name = params.dig(:inherit_classification, :parent).
                          to_s.strip_html.strip_squeeze
      parent = resolve_name!(
        @parent_text_name,
        params.dig(:inherit_classification, :options)
      )
      unless parent && make_sure_parent_has_classification!(parent) &&
             make_sure_parent_higher_rank!(parent)
        render_new and return
      end

      @name.inherit_classification(parent)
      redirect_to(@name.show_link_args)
    end

    private

    def render_new
      render("new", location: form_to_inherit_classification_of_name_path)
    end

    include Names::Classification::SharedPrivateMethods
  end
end
