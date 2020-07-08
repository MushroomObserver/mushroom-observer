# frozen_string_literal: true

# TODO: move this into a new NotificationController
class ObserverController
  # Displays notifications related to a given naming and users.
  # Inputs: params[:naming], params[:observation]
  # Outputs:
  #   @notifications
  def show_notifications # :norobots:
    pass_query_params
    data = []
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    name_tracking_emails(@user.id).each do |q|
      fields = [:naming, :notification, :shown]
      naming_id, notification_id, shown = q.get_integers(fields)
      next unless shown.nil?

      notification = Notification.find(notification_id)
      if notification.note_template
        data.push([notification, Naming.find(naming_id)])
      end
      q.add_integer(:shown, 1)
    end
    @data = data.sort_by { rand }
  end

  def name_tracking_emails(user_id)
    QueuedEmail.where(flavor: "QueuedEmail::NameTracking", to_user_id: user_id)
  end
end
