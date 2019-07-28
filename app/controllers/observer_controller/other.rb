# TODO: where does this stuff belong?
class ObserverController
  def test_flash_redirection
    tags = params[:tags].to_s.split(",")
    if tags.any?
      flash_notice(tags.pop.to_sym.t)
      redirect_to(
        controller: :observer,
        action: :test_flash_redirection,
        tags: tags.join(",")
      )
    else
      # (sleight of hand to prevent localization_file_text from complaining
      # about missing test_flash_redirection_title tag)
      @title = "test_flash_redirection_title".to_sym.t
      # debugger
      render(layout: "application", html: "")
    end
  end

  # Force javascript on.
  def turn_javascript_on # :norobots:
    session[:js_override] = :on
    flash_notice(:turn_javascript_on_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Force javascript off.
  def turn_javascript_off # :norobots:
    session[:js_override] = :off
    flash_notice(:turn_javascript_off_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Enable auto-detection.
  def turn_javascript_nil # :norobots:
    session[:js_override] = nil
    flash_notice(:turn_javascript_nil_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Simple list of all the files in public/html that are linked to the W3C
  # validator to make testing easy.
  def w3c_tests
    render(layout: false)
  end

  # Update banner across all translations.
  def change_banner # :root: :norobots:
    if !in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    elsif request.method == "POST"
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      time = Time.now
      Language.all.each do |lang|
        if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
          str.update!(
            text: @val,
            updated_at: (str.language.official ? time : time - 1.minute)
          )
        else
          str = lang.translation_strings.create!(
            tag: "app_banner_box",
            text: @val,
            updated_at: time - 1.minute
          )
        end
        str.update_localization
        str.language.update_localization_file
        str.language.update_export_file
      end
      redirect_to(action: "list_rss_logs")
    else
      @val = :app_banner_box.l.to_s
    end
  end

  # Callback to let reviewers change the export status of a Name from the
  # show_name page.
  def set_export_status # :norobots:
    pass_query_params
    id    = params[:id].to_s
    type  = params[:type].to_s
    value = params[:value].to_s
    model_class = type.camelize.safe_constantize
    if !reviewer?
      flash_error(:runtime_admin_only.t)
      redirect_back_or_default("/")
    elsif !model_class ||
          !model_class.respond_to?(:column_names) ||
          !model_class.column_names.include?("ok_for_export")
      flash_error(:runtime_invalid.t(type: '"type"', value: type))
      redirect_back_or_default("/")
    elsif !value.match(/^[01]$/)
      flash_error(:runtime_invalid.t(type: '"value"', value: value))
      redirect_back_or_default("/")
    elsif (obj = find_or_goto_index(model_class, id))
      obj.ok_for_export = (value == "1")
      obj.save_without_our_callbacks
      if params[:return]
        redirect_back_or_default("/")
      else
        controller = params[:return_controller] || obj.show_controller
        action = params[:return_action] || obj.show_action
        redirect_with_query(controller: controller,
                            action: action, id: id)
      end
    end
  end
end
