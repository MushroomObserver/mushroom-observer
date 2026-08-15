# frozen_string_literal: true

module InatImportsController::FormBuilders
  # Params carried verbatim from the new form through the confirm page.
  PASSTHROUGH_PARAM_KEYS = [
    :inat_username, :inat_ids, :inat_url, :original_inat_url, :consent,
    :recheck_all, :skip_inat_writeback, :create_skeletons
  ].freeze

  # Params that are literally "1" when checked/selected, absent or any
  # other value otherwise -- read verbatim, no per-field branching.
  CHECKBOX_FLAG_PARAMS = [:all, :consent, :import_others,
                          :recheck_all].freeze

  private

  def build_confirm_form
    FormObject::InatImportConfirm.new(
      **PASSTHROUGH_PARAM_KEYS.index_with { |key| params[key] },
      import_all: params[:all],
      import_others: (import_others? ? "1" : nil)
    )
  end

  def render_new_view(status: :ok, **render_opts)
    render(
      Views::Controllers::InatImports::New.new(
        form: build_new_form,
        super_importer: InatImport.super_importer?(@user),
        admin: in_admin_mode?,
        has_prior_imports: InatImport.exists?(user: @user)
      ),
      status: status, **render_opts
    )
  end

  # `params[...]` naturally carries a resubmission's values forward
  # (Superform's namespaced fields are already flattened to top-level
  # by flatten_new_form_params/flatten_confirm_params), and is
  # naturally blank on a fresh GET -- so this needs no separate
  # "fresh vs. reload" branch, just `params` read directly with the
  # same fallbacks either way.
  def build_new_form
    FormObject::InatImport.new(
      inat_username: params[:inat_username] || @user.inat_username,
      inat_ids: params[:inat_ids],
      inat_url: reload_inat_url,
      choose_method: params[:choose_method] || derive_choose_method,
      skip_inat_writeback: initial_skip_writeback,
      create_skeletons: initial_create_skeletons,
      **checkbox_flag_params
    )
  end

  def checkbox_flag_params
    CHECKBOX_FLAG_PARAMS.index_with { |key| "1" if params[key] == "1" }
  end

  # `normalize_inat_url_param!` overwrites params[:inat_url] in place
  # with the normalized query string, saving the pre-normalized value
  # to params[:original_inat_url] first -- prefer that original text
  # for redisplay so the user sees what they actually typed.
  def reload_inat_url
    params[:original_inat_url] || params[:inat_url]
  end

  def derive_choose_method
    return "all" if params[:all] == "1"
    return "ids" if params[:inat_ids].present?
    return "url" if reload_inat_url.present?

    "all"
  end

  # The fresh form (a GET with no params submitted at all, so
  # :skip_inat_writeback is absent from params entirely) pre-checks the
  # box to mirror the default that will apply if the admin doesn't
  # touch it: skip in development, write back in production. On reload
  # (after a POST), the key is always present -- CheckboxField's hidden
  # "0" sidecar means an unchecked box still submits the key, just with
  # value "0" -- so honor the submitted state instead.
  def initial_skip_writeback
    return ("1" if Rails.env.development?) unless
      params.key?(:skip_inat_writeback)

    ("1" if params[:skip_inat_writeback] == "1")
  end

  # The fresh form (no :create_skeletons key) pre-checks the box — building
  # a skeleton counterpart for an unlicensed import-others obs is the
  # default (#4828). On reload, honor the submitted state.
  def initial_create_skeletons
    return "1" unless params.key?(:create_skeletons)

    ("1" if params[:create_skeletons] == "1")
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
