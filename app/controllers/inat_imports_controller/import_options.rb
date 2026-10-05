# frozen_string_literal: true

# The how-to-import choices on the new-import form, as saved on the
# InatImport and read by the estimators and validators.
module InatImportsController::ImportOptions
  private

  def new_import_option_attrs
    {
      import_others: import_others?,
      create_skeletons: create_skeletons?,
      recheck_all: recheck_all?,
      writeback: writeback_policy
    }
  end

  # Does this import cover other users' observations?
  # Off for an ordinary user; a checkbox for whoever may turn it on --
  # a superimporter, or an admin importing their project (#5416).
  def import_others?
    return false unless may_import_others?

    params[:import_others] == "1"
  end

  def may_import_others?
    InatImport.super_importer?(@user) || project_admin_import?
  end

  # Import other users' unlicensed observations as placeholder skeletons?
  # (Available only if importing others' observations.)
  def create_skeletons?
    import_others? && params[:create_skeletons] == "1"
  end

  # Should an import-all / URL run re-check observations already
  # carrying iNat's "Mushroom Observer URL" field?
  # (Explicit id lists re-check regardless of this flag.)
  def recheck_all?
    params[:recheck_all] == "1"
  end

  # Skip write-back by default for admins in development mode.
  # (Lets admins test imports without affecting iNat.)
  def writeback_policy
    return :default unless in_admin_mode?

    params[:skip_inat_writeback] == "1" ? :skip : :force
  end
end
