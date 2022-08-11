# frozen_string_literal: true

# Send emails directly to webmaster and users via the application
class EmailsController < ApplicationController
  before_action :login_required, except: [
    :ask_webmaster_question
  ]

  def features
    if in_admin_mode?
      @users = User.where("email_general_feature=1 && verified is not null")
      if request.method == "POST"
        @users.each do |user|
          QueuedEmail::Feature.create_email(user,
                                            params[:feature_email][:content])
        end
        flash_notice(:send_feature_email_success.t)
        redirect_to(users_path(by: "name"))
      end
    else
      flash_error(:permission_denied.t)
      redirect_to("/")
    end
  end

  def ask_webmaster_question
    @email = params.dig(:user, :email)
    @content = params.dig(:question, :content)
    @email_error = false
    return create_webmaster_question if request.method == "POST"

    @email = @user.email if @user
  end

  def ask_user_question
    return unless (@target = find_or_goto_index(User, params[:id].to_s)) &&
                  can_email_user_question?(@user) &&
                  request.method == "POST"

    subject = params[:email][:subject]
    content = params[:email][:content]
    UserEmail.build(@user, @target, subject, content).deliver_now
    flash_notice(:runtime_ask_user_question_success.t)
    redirect_to(user_path(@target.id))
  end

  def ask_observation_question
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation &&
                  can_email_user_question?(@observation) &&
                  request.method == "POST"

    question = params[:question][:content]
    ObservationEmail.build(@user, @observation, question).deliver_now
    flash_notice(:runtime_ask_observation_question_success.t)
    redirect_with_query(controller: :observations, action: :show,
                        id: @observation.id)
  end

  def commercial_inquiry
    return unless (@image = find_or_goto_index(Image, params[:id].to_s)) &&
                  can_email_user_question?(@image,
                                           method: :email_general_commercial) &&
                  request.method == "POST"

    commercial_inquiry = params[:commercial_inquiry][:content]
    CommercialEmail.build(@user, @image, commercial_inquiry).deliver_now
    flash_notice(:runtime_commercial_inquiry_success.t)
    redirect_with_query(controller: "image", action: "show_image",
                        id: @image.id)
  end

  def can_email_user_question?(target, method: :email_general_question)
    user = target.is_a?(User) ? target : target.user
    return true if user.send(method)

    flash_error(:permission_denied.t)
    redirect_with_query(controller: target.show_controller,
                        action: target.show_action, id: target.id)
    false
  end

  def merge_request
    @model = validate_merge_model!(params[:type])
    return unless @model

    @old_obj = @model.safe_find(params[:old_id])
    @new_obj = @model.safe_find(params[:new_id])
    if !@old_obj || !@new_obj || @old_jb == @new_obj
      redirect_back_or_default("/")
      return
    end
    send_merge_request if request.method == "POST"
  end

  # get emails_name_change_request(
  #   params: {
  #     name_id: 1258, new_name_with_icn_id: "Auricularia Bull. [#17132]"
  #   }
  # )
  def name_change_request
    @name = Name.safe_find(params[:name_id])
    name_with_icn_id = "#{@name.search_name} [##{@name.icn_id}]"

    if name_with_icn_id == params[:new_name_with_icn_id]
      redirect_back_or_default("/")
      return
    end

    @new_name_with_icn_id = params[:new_name_with_icn_id]
    return unless request.method == "POST"

    send_name_change_request(name_with_icn_id, @new_name_with_icn_id)
  end

  ##########

  private

  def create_webmaster_question
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
      redirect_to("/")
    end
  end

  def non_user_potential_spam?
    !@user && (
      /https?:/.match?(@content) ||
      %r{<[/a-zA-Z]+>}.match?(@content) ||
      @content.exclude?(" ")
    )
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
      redirect_back_or_default("/")
      nil
    end
  end

  def send_merge_request
    temporarily_set_locale(MO.default_locale) do
      subject = "#{@model.name} Merge Request"
      WebmasterEmail.build(@user.email, merge_request_content, subject).
        deliver_now
    end
    flash_notice(:email_merge_request_success.t)
    redirect_to(@old_obj.show_link_args)
  end

  def merge_request_content
    :email_merge_objects.l(
      user: @user.login,
      type: @model.type_tag,
      this: @old_obj.merge_info,
      that: @new_obj.merge_info,
      show_this_url: @old_obj.show_url,
      show_that_url: @new_obj.show_url,
      edit_this_url: @old_obj.edit_url,
      edit_that_url: @new_obj.edit_url,
      notes: params[:notes].to_s.strip_html.strip_squeeze
    )
  end

  def send_name_change_request(name_with_icn_id, new_name_with_icn_id)
    temporarily_set_locale(MO.default_locale) do
      subject = "Request to change Name having dependents"
      content = change_request_content(name_with_icn_id, new_name_with_icn_id)
      WebmasterEmail.build(@user.email, content, subject).
        deliver_now
    end
    flash_notice(:email_change_name_request_success.t)
    redirect_to(@name.show_link_args)
  end

  def change_request_content(name_with_icn_id, new_name_with_icn_id)
    :email_name_change_request.l(
      user: @user.login,
      old_name: name_with_icn_id,
      new_name: new_name_with_icn_id,
      show_url: @name.show_url,
      edit_url: @name.edit_url,
      notes: params[:notes].to_s.strip_html.strip_squeeze
    )
  end

  def temporarily_set_locale(locale)
    old_locale = I18n.locale
    # Setting I18n.locale used to incur a significant performance penalty,
    # avoid doing so if not required.  Not sure if this is still the case.
    I18n.locale = locale if I18n.locale != locale
    yield
  ensure
    I18n.locale = old_locale if I18n.locale != old_locale
  end
end
