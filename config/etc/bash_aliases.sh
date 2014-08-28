export TZ='Eastern Time (US & Canada)'
export RAILS_ENV=production

# Jason's minimal aliases:
alias dir='ls -AF'
alias dirf='ls -AlF'
alias dirt='ls -AlrtF'
alias dirz='ls -lF'
alias dird='ls -lF | grep ^d'
alias dirx='ls -AdlF [^.]* | grep -v "^[ld]"'
alias cd..='cd ..'
alias rd='rmdir'
alias md='mkdir'
alias cls='clear'
alias del='rm -f'
alias mv='mv -i'
alias cp='cp -i'
alias grep='grep -s'
function pfind {
  find $2 -type f -exec egrep -H $1 \{} \;
}

alias mo='cd /var/web/mo'

alias mosql="mysql -u mo -p'k498dnt4' mo_production"
function mosqle {
  mysql -u mo -p'k498dnt4' mo_production -e "source $1"
}

function uni {
  case $1 in
    show)
      ps -ef | grep unicorn ;;
    start)
      unicorn_rails -c /var/web/mo/config/unicorn.rb -D ;;
    reload)
      kill -HUP `cat /var/web/mo/tmp/unicorn.pid` ;;
    stop)
      kill -QUIT `cat /var/web/mo/tmp/unicorn.pid` ;;
    kill)
      kill -TERM `cat /var/web/mo/tmp/unicorn.pid` ;;
    *)
      echo
      echo "USAGE: uni <command>"
      echo
      echo COMMANDS:
      echo "  show     Show unicorn processes."
      echo "  start    Start unicorn."
      echo "  reload   Reload application."
      echo "  stop     Shutdown unicorn and workers gracefully, waiting for them to"
      echo "           finish serving their last request."
      echo "  kill     Kill unicorn and workers immediately."
      echo
  esac
}
