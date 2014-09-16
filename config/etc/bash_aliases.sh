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

alias uni='service unicorn'

alias mosql='mysql -u mo -h xxx -p"xxx" mo_production'

function mosqle {
  mysql -u mo -h xxx -p"xxx" mo_production -e "source $1"
}
