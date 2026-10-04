# frozen_string_literal: true

module Views::Controllers::Projects::Admin
  class AlertPanel
    # One checkbox: whether the admin reading the page is one of the
    # people this project's alerts go to. Bound to the ProjectExternalSite
    # so the form knows which site it speaks for, but the value is the
    # reader's membership of its recipient list, not a column.
    class Form < ::Components::ApplicationForm
      prop :project, ::Project
      prop :user, ::User
      prop :site_name, String

      def initialize(model, **attrs)
        super(model, turbo: true, **attrs)
      end

      def view_template
        super do
          checkbox_field("subscribed",
                         label: :project_alerts_subscribe.l(site: @site_name),
                         checked: model.alerts?(@user))
          submit(:save.ti, class: "mt-2")
        end
      end

      def form_action
        project_alert_subscription_path(project_id: @project.id, id: model.id)
      end
    end
  end
end
