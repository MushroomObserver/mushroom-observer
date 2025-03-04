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
alias ga='git add'
alias gb='git branch'
alias gc='git commit'
alias gd='git diff'
alias gk='git checkout'
alias gs='git status'
alias grep='grep -s'
alias lu='script/lookup_user'
function pfind {
  find $2 -type f -exec egrep -H $1 \{} \;
}

alias mo='cd /var/web/mo'

alias uni='/etc/init.d/unicorn'
alias deploy='script/deploy.sh'

alias mosql='mysql --defaults-extra-file=/var/web/mo/config/mysql-production.cnf'

function mosqle {
  mysql --defaults-extra-file=/var/web/mo/config/mysql-production.cnf -e "source $1"
}
