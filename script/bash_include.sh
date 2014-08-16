path=(/usr/local/bin /usr/bin /bin)
webmaster_email=webmaster@mushroomobserver.org

[[ $RAILS_ENV == "production" ]] && production=1 || production=0
[[ $RAILS_ENV == "test" ]] && testing=1 || testing=0
(( !$production && !testing )) && development=1 || development=0

# This flag gets set to 1 if any 'run' or 'run_mysql' commands fail.
errors=0

# Application root = $RAIlS_ROOT.
app_root="$( cd "$(dirname "$0")"; pwd -P | sed 's/\/script.*//' )"

# Temporary log file, e.g., $RAILS_ROOT/log/process_image.1234
log_file=$app_root/log/$( basename $0 ).$$

# Tell it to keep a running log of all the times this script is run.
function keep_cumulative_log {
  cumulative_log_file=$app_root/log/$( basename $0 ).log
}

# Clean up logs before exit.
function clean_log {
  if [[ $cumulative_log_file != "" && -e $log_file ]]; then
    cat $log_file >> $cumulative_log_file
  fi
  rm -f $log_file
}
trap clean_log EXIT

# Get mysql login information.
config=$app_root/config/database.yml
db_database=$( grep -A 20 $RAILS_ENV: $config | grep database: | head -1 | sed "s/.*: *//" )
db_username=$( grep -A 20 $RAILS_ENV: $config | grep username: | head -1 | sed "s/.*: *//" )
db_password=$( grep -A 20 $RAILS_ENV: $config | grep password: | head -1 | sed "s/.*: *//" )

# Get a list of image servers.
for config in \
  $app_root/config/consts-site.rb \
  $app_root/config/consts.rb
do
  if [[ $(grep -c IMAGE_SOURCES $config) -gt 0 ]]; then
    img_config=$config
    break
  fi
done
declare -a image_servers=( $(sed -n '/IMAGE_SOURCES/,/^}/p' $img_config | grep :write | sed -e 's/.*"\(.*\)".*/\1/') )

function time_stamp {
  date "+%Y%m%d %H:%M:%S %Z"
}

# Wait until no other processes are running the given command(s). Examples:
#   wait_for scp
#   wait_for "(convert|jpegresize)"
function wait_for() {
  while (ps -e | grep " $*\$" > /dev/null); do sleep 5; done
}

# Run the given command, logging date and any stdout or stderr. Example:
#   run convert -thumbnail 200x200 large.jpg thumb.jpg
function run() {
  echo $(time_stamp)">" $* >> $log_file
  if !($* >> $log_file 2>&1); then
    errors=1
    echo "**** FAILED ****" >> $log_file
    return 1
  else
    return 0
  fi
}

# Run the given mysql command, logging the command and any errors. Example:
#   run_mysql "UPDATE images SET transferred=true WHERE id=$id"
function run_mysql() {
  echo "$(time_stamp)>" mysql "\"$*\"" >> $log_file
  if !( mysql -q -u "$db_username" -p"$db_password" "$db_database" -e "$*" >> $log_file 2>&1 ); then
    errors=1
    echo "**** FAILED ****" >> $log_file
    return 1
  else
    return 0
  fi
}
