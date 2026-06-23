# frozen_string_literal: true

module Views::Controllers::Herbaria
  class Show
    # Curators list rendered above the add-curator form on
    # `Herbaria::Show`. Uses `Components::Table` with the
    # `t.heading { ... }` section-heading row (single colspan th)
    # rather than per-column headers.
    class CuratorTable < Views::Base
      prop :herbarium, ::Herbarium

      def view_template
        render(::Components::Table.new(
                 @herbarium.curators, class: "table-striped table-curators"
               )) do |t|
          t.heading { plain("#{heading_label}:") }
          t.column("delete") { |user| render_delete_cell(user) } if can_delete?
          t.column("user") { |user| render_user_cell(user) }
        end
      end

      private

      def can_delete?
        @herbarium.curator?(current_user) || in_admin_mode?
      end

      def heading_label
        if @herbarium.curators.length == 1
          :herbarium_curator.t
        else
          :herbarium_curators.t
        end
      end

      def render_delete_cell(user)
        render(::Components::CRUDButton::Delete.new(
                 name: "X",
                 target: herbaria_curator_path(@herbarium, user: user.id),
                 id: "delete_herbarium_curator_link_#{user.id}",
                 btn: nil
               ))
      end

      def render_user_cell(user)
        render(::Components::Link::Object::User.new(user: user,
                                                    name: user.legal_name))
      end
    end
  end
end
