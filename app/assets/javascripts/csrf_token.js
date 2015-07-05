var CSRF_TOKEN = null;
function csrf_token() {
  if (!CSRF_TOKEN)
    CSRF_TOKEN = jQuery("[name='csrf-token']").attr('content');
  return(CSRF_TOKEN);
}
