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
      return rubric unless (ctrlr = nav_linkable_controller)

      link_to(
        rubric,
        { controller: "/#{ctrlr.controller_path}", action: :index },
        class: "#{ctrlr.controller_name}_index_link",
        data: { toggle: "tooltip", placement: :bottom,
                title: :INDEX_OBJECT.t(type: ctrlr.controller_name.to_sym) }
      )
    end

    # Check for a linkable (parent?) controller and return the path
    def nav_linkable_controller
      ctrlr = if (klass = nav_linkable_parent_controller)
                klass.constantize.new
              else
                controller
              end
      return false unless ctrlr.methods.include?(:index) &&
                          NAV_INDEXABLES.include?(ctrlr.controller_name)

      ctrlr
    end

    def nav_linkable_parent_controller
      unless (parent = parent_controller_module) &&
             Object.const_defined?(klass = "::#{parent}Controller")
        return false
      end

      klass
    end

    NAV_INDEXABLES = %w[
      observations names species_lists projects locations images herbaria
      glossary_terms comments rss_logs field_slips
    ].freeze

    # Descriptions also don't get a create button
    # Herbarium records are created via Observations, not from the index
    #
    # Renders a solid-green button with `aria-label` / `title` =
    # "New Observation" / "New Name" / etc. (#3930). On phones
    # (below `$screen-sm-min` / 768px) the button is just the `+`
    # glyph — long localizations like "Listes d'observations
    # [Ajouter]" don't fit alongside the page rubric on a 360px
    # viewport (matches iNat's mobile pattern). On `sm` and above
    # the "Add" label appears next to the glyph.
    def nav_create(user, controller)
      return "" unless nav_create_visible?(user, controller)

      link_to(
        { controller: "/#{controller.controller_path}", action: :new },
        nav_create_link_options(controller)
      ) { nav_create_content }
    end

    private

    def nav_create_visible?(user, controller)
      user && controller.methods.include?(:new) &&
        NAV_CREATABLES.include?(controller.controller_name)
    end

    def nav_create_link_options(controller)
      obj_name = controller.controller_model_name.underscore.upcase.to_sym.l
      full_label = [:NEW.l, obj_name].safe_join(" ")
      {
        class: "btn btn-success btn-sm ml-1 mr-0 mx-sm-3 top_nav_button",
        title: full_label,
        aria: { label: full_label },
        data: { toggle: "tooltip" }
      }
    end

    def nav_create_content
      safe_join([
                  link_icon(:add),
                  tag.span(:ADD.l, class: "d-none d-sm-inline ml-1")
                ])
    end

    public

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
