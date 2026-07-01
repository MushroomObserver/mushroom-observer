# frozen_string_literal: true

module InatImportsController::FormBuilders
  private

  def build_confirm_form
    FormObject::InatImportConfirm.new(
      inat_username: params[:inat_username],
      inat_ids: params[:inat_ids],
      inat_url: params[:inat_url],
      original_inat_url: params[:original_inat_url],
      import_all: params[:all],
      consent: params[:consent],
      import_others: (import_others? ? "1" : nil),
      skip_inat_writeback: params[:skip_inat_writeback]
    )
  end

  def reload_form
    render_new_form(submitted: reload_form_params)
  end

  def reload_form_params
    base_reload_params.merge(constraint_reload_params)
  end

  def base_reload_params
    {
      username: params[:inat_username],
      consent: params[:consent],
      import_others: params[:import_others],
      skip_writeback: params[:skip_inat_writeback]
    }
  end

  def constraint_reload_params
    {
      inat_ids: params[:inat_ids],
      inat_url: params[:original_inat_url] || params[:inat_url],
      all: params[:all],
      choose_method: params[:choose_method]
    }
  end

  def render_new_form(submitted: {})
    render(
      Views::Controllers::InatImports::New.new(
        form: build_new_form(submitted),
        super_importer: InatImport.super_importer?(@user),
        admin: in_admin_mode?
      )
    )
  end

  def build_new_form(submitted)
    FormObject::InatImport.new(
      inat_username: submitted.fetch(:username, @user.inat_username),
      inat_ids: submitted[:inat_ids],
      inat_url: submitted[:inat_url],
      all: ("1" if submitted[:all] == "1"),
      choose_method: submitted[:choose_method] ||
                     derive_choose_method(submitted),
      consent: ("1" if submitted[:consent] == "1"),
      import_others: ("1" if submitted[:import_others] == "1"),
      skip_inat_writeback: initial_skip_writeback(submitted)
    )
  end

  def derive_choose_method(submitted)
    return "all" if submitted[:all] == "1"
    return "ids" if submitted[:inat_ids].present?
    return "url" if submitted[:inat_url].present?

    "all"
  end

  # The fresh form (no :skip_writeback key) pre-checks the box to mirror the
  # default that will apply if the admin doesn't touch it: skip in
  # development, write back in production. On reload, honor the submitted
  # state.
  def initial_skip_writeback(submitted)
    return ("1" if Rails.env.development?) unless
      submitted.key?(:skip_writeback)

    ("1" if submitted[:skip_writeback] == "1")
  end

  # Superform namespaces hidden fields under the model key.
  # Flatten them to top-level so the rest of the controller works unchanged.
  def flatten_confirm_params
    confirm = params[:inat_import_confirm]
    return unless confirm

    merge_form_param(confirm, :inat_username)
    merge_form_param(confirm, :inat_ids)
    merge_form_param(confirm, :inat_url)
    merge_form_param(confirm, :original_inat_url)
    merge_form_param(confirm, :consent)
    merge_form_param(confirm, :import_others)
    merge_form_param(confirm, :skip_inat_writeback)
    params[:all] ||= confirm[:import_all]
  end

  def merge_form_param(form_params, key)
    params[key] ||= form_params[key]
  end

  # Superform namespaces fields under the model key.
  # Flatten them to top-level so the controller works unchanged.
  def flatten_new_form_params
    new_form = params[:inat_import]
    return unless new_form

    merge_form_param(new_form, :inat_username)
    merge_form_param(new_form, :inat_ids)
    merge_form_param(new_form, :inat_url)
    merge_form_param(new_form, :consent)
    merge_form_param(new_form, :import_others)
    merge_form_param(new_form, :skip_inat_writeback)
    merge_form_param(new_form, :choose_method)
    params[:all] = "1" if params[:choose_method] == "all"
    params[:all] ||= new_form[:all]
  end
end
