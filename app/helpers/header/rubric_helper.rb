# frozen_string_literal: true

#  nav_rubric           # The top nav title, which may link to an index
#  nav_create           # Top nav create_link
#  nav_scan_qr_code     # Top nav qr code link, for Obs and FieldSlips
#
module Header
  module RubricHelper
    # The idea here is to make the rubric link to an unfiltered index, or
    # in the case of nested controllers, the parent controller's index,
    # if an index link would be relevant.
    def nav_rubric(query)
      params = query&.params&.except(:order_by)
      if action_name == "index" && (!params || params&.blank?)
        rubric
      else
        nav_index_link(rubric)
      end
    end

    def nav_index_link(rubric)
      return rubric unless (path = nav_linkable_controller_path)

      model_name = controller.controller_model_name.pluralize.underscore
      link_to(
        rubric,
        { controller: "/#{path}", action: :index },
        class: "#{model_name}_index_link",
        data: { toggle: "tooltip", placement: :bottom,
                title: :INDEX_OBJECT.t(type: model_name.to_sym) }
      )
    end

    # Check for a linkable (parent?) controller and return the path
    def nav_linkable_controller_path
      ctrlr = if (parent = parent_controller_module) &&
                 Object.const_defined?(klass = "::#{parent}Controller")
                klass.constantize.new
              else
                controller
              end
      return false unless ctrlr.methods.include?(:index) &&
                          NAV_INDEXABLES.include?(ctrlr.controller_name)

      ctrlr.controller_path
    end

    NAV_INDEXABLES = %w[
      observations names species_lists projects locations images herbaria
      glossary_terms comments rss_logs field_slips
    ].freeze

    # Descriptions also don't get a create button
    # Herbarium records are created via Observations, not from the index
    def nav_create(user, controller)
      unless user &&
             controller.methods.include?(:new) &&
             NAV_CREATABLES.include?(controller.controller_name)
        return ""
      end

      obj_name = controller.controller_model_name.underscore.upcase.to_sym.l

      link_to(
        link_icon(:add, title: [:NEW.l, obj_name].safe_join(" ")),
        { controller: "/#{controller.controller_path}", action: :new },
        class: "btn btn-sm btn-outline-default ml-1 mr-0 mx-sm-3 top_nav_button"
      )
    end

    NAV_CREATABLES = %w[
      observations names species_lists projects locations images herbaria
      glossary_terms field_slips articles publications
    ].freeze

    def nav_scan_qr_code(user, controller)
      unless user &&
             %w[observations field_slips].include?(controller.controller_name)
        return ""
      end

      link_to(
        link_icon(:qrcode, title: :app_qrcode.l),
        field_slips_qr_reader_new_path,
        class: "btn btn-sm btn-outline-default mx-0 mx-sm-2 top_nav_button"
      )
    end
  end
end
