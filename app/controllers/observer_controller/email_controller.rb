# frozen_string_literal: true

# TODO: move this into a new EmailController
# Send emails directly to webmaster and users via the application
class ObserverController
  def email_features
    if in_admin_mode?
      @users = User.where("email_general_feature=1 && verified is not null")
      if request.method == "POST"
        @users.each do |user|
          QueuedEmail::Feature.create_email(user,
                                            params[:feature_email][:content])
        end
        flash_notice(:send_feature_email_success.t)
        redirect_to(action: "users_by_name")
      end
    else
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  def ask_webmaster_question
    init_webmaster_question_instance_vars
    if @email.blank? || @email.index("@").nil?
      flash_error(:runtime_ask_webmaster_need_address.t)
      @email_error = true
    elsif @content.blank?
      flash_error(:runtime_ask_webmaster_need_content.t)
    elsif non_user_potential_spam?
      flash_error(:runtime_ask_webmaster_antispam.t)
    else
      WebmasterEmail.build(@email, @content).deliver_now
      flash_notice(:runtime_ask_webmaster_success.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  def ask_user_question
    return unless (@target = find_or_goto_index(User, params[:id].to_s)) &&
                  email_question(@user) &&
                  request.method == "POST"

    subject = params[:email][:subject]
    content = params[:email][:content]
    UserEmail.build(@user, @target, subject, content).deliver_now
    flash_notice(:runtime_ask_user_question_success.t)
    redirect_to(action: "show_user", id: @target.id)
  end

  def ask_observation_question
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation &&
                  email_question(@observation) &&
                  request.method == "POST"

    question = params[:question][:content]
    ObservationEmail.build(@user, @observation, question).deliver_now
    flash_notice(:runtime_ask_observation_question_success.t)
    redirect_with_query(action: "show_observation", id: @observation.id)
  end

  def commercial_inquiry
    return unless (@image = find_or_goto_index(Image, params[:id].to_s)) &&
                  email_question(@image, :email_general_commercial) &&
                  request.method == "POST"

    commercial_inquiry = params[:commercial_inquiry][:content]
    CommercialEmail.build(@user, @image, commercial_inquiry).deliver_now
    flash_notice(:runtime_commercial_inquiry_success.t)
    redirect_with_query(controller: "image", action: "show_image",
                        id: @image.id)
  end

  def email_question(target, method = :email_general_question)
    result = false
    user = target.is_a?(User) ? target : target.user
    if user.send(method)
      result = true
    else
      flash_error(:permission_denied.t)
      redirect_with_query(controller: target.show_controller,
                          action: target.show_action, id: target.id)
    end
    result
  end

  def email_merge_request
    @model = validate_merge_model!(params[:type])
    return unless @model

    @old_obj = @model.safe_find(params[:old_id])
    @new_obj = @model.safe_find(params[:new_id])
    if !@old_obj || !@new_obj || @old_jb == @new_obj
      redirect_back_or_default(action: :index)
      return
    end
    send_request if request.method == "POST"
  end

  # get email_name_change_request(
  #   params: {
  #     name_id: 1258, new_name_with_icn_id: "Auricularia Bull. [#17132]"
  #   }
  # )
  def email_name_change_request
    @name = Name.safe_find(params[:name_id])
    name_with_icn_id = "#{@name.search_name} [##{@name.icn_id}]"

    if name_with_icn_id == params[:new_name_with_icn_id]
      redirect_back_or_default(action: :index)
      return
    end

    @new_name_with_icn_id = params[:new_name_with_icn_id]
    return unless request.method == "POST"

    send_name_change_request(name_with_icn_id, @new_name_with_icn_id)
  end

  ##########

  private

  def init_webmaster_question_instance_vars
    @email = params.dig(:user, :email)
    @content = params.dig(:question, :content)
    @email_error = false
    return if request.method == "POST"

    @email = @user.email if @user
  end

  def non_user_potential_spam?
    !@user &&
      (/https?:/ =~ @content || %r{<[/a-zA-Z]+>} =~ @content ||
       !@content.include?(" "))
  end

  def validate_merge_model!(val)
    case val
    when "Herbarium"
      Herbarium
    when "Location"
      Location
    when "Name"
      Name
    else
      flash_error("Invalid type param: #{val.inspect}.")
      redirect_back_or_default(action: :index)
      nil
    end
  end

  def send_request
    change_locale_if_needed(MO.default_locale)
    subject = "#{@model.name} Merge Request"
    content = :email_merge_objects.l(
      user: @user.login,
      type: @model.type_tag,
      this: @old_obj.merge_info,
      that: @new_obj.merge_info,
      this_url: @old_obj.show_url,
      that_url: @new_obj.show_url,
      notes: params[:notes].to_s.strip_html.strip_squeeze
    )
    WebmasterEmail.build(@user.email, content, subject).deliver_now
    flash_notice(:email_merge_request_success.t)
    redirect_to(@old_obj.show_link_args)
  end

  def send_name_change_request(name_with_icn_id, new_name_with_icn_id)
    change_locale_if_needed(MO.default_locale)
    subject = "Request to change Name having dependents"
    content = :email_name_change_request.l(
      user: @user.login,
      name: name_with_icn_id,
      name_url: @name.show_url,
      new_name: new_name_with_icn_id,
      notes: params[:notes].to_s.strip_html.strip_squeeze
    )
    WebmasterEmail.build(@user.email, content, subject).deliver_now
    flash_notice(:email_change_name_request_success.t)
    redirect_to(@name.show_link_args)
  end
end
