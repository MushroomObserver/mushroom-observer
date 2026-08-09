# frozen_string_literal: true

module InatImportsController::FormBuilders
  # Params carried verbatim from the new form through the confirm page.
  PASSTHROUGH_PARAM_KEYS = [
    :inat_username, :inat_ids, :inat_url, :original_inat_url, :consent,
    :recheck_all, :skip_inat_writeback
  ].freeze

  private

  def build_confirm_form
    FormObject::InatImportConfirm.new(
      **PASSTHROUGH_PARAM_KEYS.index_with { |key| params[key] },
      import_all: params[:all],
      import_others: (import_others? ? "1" : nil)
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
      recheck_all: params[:recheck_all],
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
        admin: in_admin_mode?,
        has_prior_imports: InatImport.exists?(user: @user)
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
      recheck_all: ("1" if submitted[:recheck_all] == "1"),
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

    (PASSTHROUGH_PARAM_KEYS + [:import_others]).each do |key|
      merge_form_param(confirm, key)
    end
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

    keys = PASSTHROUGH_PARAM_KEYS - [:original_inat_url] +
           [:import_others, :choose_method]
    keys.each { |key| merge_form_param(new_form, key) }
    params[:all] = "1" if params[:choose_method] == "all"
    params[:all] ||= new_form[:all]
  end
end
