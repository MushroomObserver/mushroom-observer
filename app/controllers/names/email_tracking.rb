# frozen_string_literal: true

# see app/controllers/names_controller.rb
class NamesController

  ##############################################################################
  #
  #  :section: Email Tracking
  #
  ##############################################################################

  # Form accessible from show_name that lets a user setup tracker notifications
  # for a name.
  def email_tracking
    pass_query_params
    name_id = params[:id].to_s
    @name = find_or_goto_index(Name, name_id)
    return unless @name

    flavor = Notification.flavors[:name]
    @notification = Notification.
                    find_by_flavor_and_obj_id_and_user_id(flavor, name_id,
                                                          @user.id)
    if request.method != "POST"
      initialize_tracking_form
    else
      submit_tracking_form(name_id)
    end
  end

  def initialize_tracking_form
    unless @name.at_or_below_genus?
      flash_warning(:email_tracking_enabled_only_for.t(name: @name.display_name,
                                                       rank: @name.rank))
    end
    if @notification
      @note_template = @notification.note_template
    else
      @note_template = :email_tracking_note_template.l(
        species_name: @name.real_text_name,
        mailing_address: @user.mailing_address_for_tracking_template,
        users_name: @user.legal_name
      )
    end
  end

  def submit_tracking_form(name_id)
    case params[:commit]
    when :ENABLE.l, :UPDATE.l
      note_template = params[:notification][:note_template]
      note_template = nil if note_template.blank?
      if @notification.nil?
        @notification = Notification.new(flavor: :name,
                                         user: @user,
                                         obj_id: name_id,
                                         note_template: note_template)
        flash_notice(:email_tracking_now_tracking.t(name: @name.display_name))
      else
        @notification.note_template = note_template
        flash_notice(:email_tracking_updated_messages.t)
      end
      @notification.save
    when :DISABLE.l
      @notification.destroy
      flash_notice(
        :email_tracking_no_longer_tracking.t(name: @name.display_name)
      )
    end
    # redirect_with_query(
    #   action: :show,
    #   id: name_id
    # )
    redirect_to name_path(@name.id, :q => get_query_param)
  end

end
