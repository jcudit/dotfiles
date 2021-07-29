go-profile () {

	cat <<EOF
	cpuprofile := "cpuprofile"
	runtime.SetCPUProfileRate(5000)
	f, _ := os.Create(cpuprofile)
	defer f.Close()
	pprof.StartCPUProfile(f)
	pprof.StopCPUProfile()
EOF

}

uilive () {
  echo "\033[2K" | pb
}

kill-dotcom () {
  ps -ax | grep ttys | grep -v -e ttys000 -e ttys001 | cut -d ' ' -f 1 | xargs -I {} kill {}
}




flame () {
  echo "https://github.com${1}?flamegraph=1&flamegraph_interval=100&flamegraph_output=raw"
}

explain () {
  echo "EXPLAIN $@" | tr '?' '0' | pb
}



pacc () {
  test_cases () {
    grep -nr "func Test" . | grep -v vendor | \
    cut -d ' ' -f 2 | cut -d "(" -f 1 | grep TestAcc
  }

  run_test () {
    if ! [[ "${1}" == "${RUN_FILTER}"* ]]; then
      echo "Skipping test $1 as it does not match the RUN_FILTER (${RUN_FILTER})"
      return 0
    else
      # FIXME: Running one test case per UNIX process yields less flaky results
      TF_ACC=1 go test -v -timeout 30m  ./... -run $1
      return $?
    fi
  }

  echo $(test_cases) | parallel --jobs 2 run_test {}
}


collapse () {
  echo "
<details><summary>$@</summary>
<p>

</p>
</details>
" | pb
}


acc () {
  org=$(echo $1 | cut -d: -f1)
  branch=$(echo $1 | cut -d: -f2)
  # git remote add $org  https://github.com/$org/terraform-provider-github.git
  git fetch $org
  nb $branch
  for i in $(git log $org/$branch ^origin/master --pretty=oneline | tac | cut -d' ' -f1); do
    git cherry-pick $i;
  done
}

h () {
  howdoi -n3 $@
}

pa () {
  script/plan $@ && \
  script/apply $@
}


showci () {
  repo=$(pwd | sed 's/.*\///')
  branch=$(git rev-parse --abbrev-ref HEAD)
  open "https://github.com/github/$repo/commit/$branch"
}

compare () {
  repo=$(pwd | sed 's/.*\///')
  branch=$(git rev-parse --abbrev-ref HEAD)
  open "https://github.com/github/$repo/compare/$branch?expand=1"
}

assume () {

  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <account_id>" >&2
    return 1
  fi

  export ACCOUNT_ID="${1}"

  awssume --profile primary  || return 1

  JSON_BLOB=$(aws --profile primary sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
    --role-session-name=jcudit-debug
  )

  cat <<EOF | tee -a ~/.aws/credentials

[${ACCOUNT_ID}]
aws_access_key_id = $(echo "${JSON_BLOB}" | jq -rc '.Credentials.AccessKeyId')
aws_secret_access_key = $(echo "${JSON_BLOB}" | jq -rc '.Credentials.SecretAccessKey')
aws_session_token = $(echo "${JSON_BLOB}" | jq -rc '.Credentials.SessionToken')
EOF
}

state () {

  if [ "$#" -ne 2 ] ; then
    echo "Usage: $0 <serial> <state>" >&2
    return 1
  fi

  echo "c = Chassis.find_by_serial_number(\"$1\");  c.state = \"$2\"; c.save; c.reload.state" | pbcopy
  echo "Copied to clipboard"
}

co () {
  git checkout $@
}

pause-deployment () {
  kctl ${1} rollout pause deployment/$(echo ${2} | sed 's/-production//') --namespace ${2}
  kctl ${1} rollout status deployment/$(echo ${2} | sed 's/-production//') --namespace ${2}
}

undo-deployment () {
  kctl ${1} rollout undo deployment/$(echo ${2} | sed 's/-production//') --namespace ${2}
}

deployment-triage () {
  if [ "$#" -ne 2 ] ; then
    echo 'Usage: deployment-triage <cluster> <namespace>' >&2
    return 1
  fi
  ssh $(kubectl-jump ${1}) \
    "sudo KUBECONFIG=/etc/kubernetes/kubelet.conf kubectl describe deployments --namespace ${2}"
  echo "---"
  ssh $(kubectl-jump ${1}) \
    "sudo KUBECONFIG=/etc/kubernetes/kubelet.conf kubectl describe rs --namespace ${2}"
}

watch-namespace-events () {
  watch -d -n2 --exec /bin/bash -c \
    "source ~/.shell/functions.bash; namespace-events ${1} ${2}"
}

namespace-events () {
  if [ "$#" -ne 2 ] ; then
    echo 'Usage: namespace-events <cluster> <namespace>' >&2
    return 1
  fi
  ssh $(kubectl-jump ${1}) \
    "sudo KUBECONFIG=/etc/kubernetes/kubelet.conf kubectl get event --namespace ${2}"
}

kubectl-jump () {
  curl -s -k "https://x:$(secret SITES_API_PASSWORD)@sites.github.net/clusters" | \
    jq -r ".[]| select(.name == \"${1}\") | .instances[-1]"
}

kctl () {
  cluster="${1}"
  shift 1
  ssh $(kubectl-jump $cluster) \
    "sudo KUBECONFIG=/etc/kubernetes/kubelet.conf kubectl $@"
}

app-role-container () {
  export SITES_API_PASSWORD=$(secret SITES_API_PASSWORD)
  z pupp
  DISTRIBUTION=stretch JANKY_BRANCH=master JOB_NAME="puppet-integration-$1-gpanel-stretch-full" script/cibuild-puppet-integration-docker-compose
}


chassis () {
  . ~/go/src/github.com/github/chassis/.env
  ~/go/bin/chassis $@
}

ap () {
  # export VAULT_NONINTERACTIVE=1; echo "${GITHUB_PASSWORD}" | . vault-login
  . script/assume-privs --force
}

modup ()  {
  GO111MODULE=on go get -u ./...
}

modv ()  {
  GO111MODULE=on go mod vendor
}

awssume () {
  ~/github/awssume/bin/awssume $@
}

watch-pstree () {
  echo watch -d -n0.5 "\"ps faux | sed '0,/init/ d'\"" | pb
}

cmc () {
  site=$(gh-site $1)
  upper_site=$(echo $site | tr '[:lower:]' '[:upper:]' | tr '-' '_')
  serial=$(curl -s https://$(secret GPANEL_TOKEN_${upper_site})@gpanel.${site}.github.net/chasses/$1 | grep "Parent Chassis" -A1 | tail -n1 | cut -d '"' -f 2 | cut -d/ -f5 | tr -d ' ')
  curl -s https://$(secret GPANEL_TOKEN_${upper_site})@gpanel.${site}.github.net/chasses/$serial | grep CMC -A3 | tail -n1 | egrep -o "\d+\.\d+\.\d+\.\d+"
}

instances () {
  app=$1
  role=$2
  curl -vvv "https://x:$(secret SITES_API_PASSWORD)@sites.github.net/instances?site=am4-ams&app=${app}&role=${role}"
  # curl -s -k \
  #   "https://x:$(secret SITES_API_PASSWORD)@sites.github.net/instances?site=am4-ams&app=${app}&role=${role}" | jq
}

gh-dig () {
  dig @10.127.5.10 $@
}

comment () {
  # comment https://github.com/github/prod-datacenter/issues/1159
  url=$1
  repo=$(echo $url | cut -d/ -f 5)
  issue=$(echo $url | cut -d/ -f 7)
  z $repo
  EDITOR="atom -w" ghi comment -v $issue
}

dd () {
  service=$1
  case $service in
    "glb")
      echo "https://app.datadoghq.com/dash/172678/glbservices" | pb ;;
    "mysql")
      echo "https://app.datadoghq.com/dash/191258/mysqloverview" | pb ;;
  esac
  echo "Clipped"
}


rebase_loop () {
  delay=${1:-"600"}

  while true; do
    echo sleeping $delay
    sleep $delay
    echo testing for changes to rebase to
    rebma | grep "Current branch ops-vpn-am4 is up to date" && rebma && frc
  done
}


ans () {
  z ansible
  . script/authenticate
  . script/ansible
  ansible
}

rebma () {
  git fetch --all; git rebase origin/master
}

rebmn () {
  git fetch --all; git rebase origin/main
}

pup () {
  echo sudo /usr/local/sbin/puppet agent --server=puppetproxy.githubapp.com --test --logdest console --color=false --environment=production | pbcopy
  echo "Copied to clipboard"
}

shl () {
  docker run  --detach-keys "ctrl-a,a" --privileged -it debian:stretch /bin/bash -i
}

kill_dcs_ci () {
  echo "sudo kill -12 \$(ps faux | egrep ^jenkins | grep cibuild | head -1 | awk '{ print \$2 }')" | pbcopy
  echo "Copied to clipboard"
  ssh network-labs-80a8afc.cp1-iad.github.net
}


function issue () {
  open $(EDITOR="atom -w" hub issue create --edit)
}

function dce_serving () {
  for host in ops-imageserve-59b4be8.sdc42-sea.github.net ops-imageserve-309c93f.sdc42-sea.github.net ops-imageserve-5ad5d84.cp1-iad.github.net ops-imageserve-bf2bbac.cp1-iad.github.net; do  echo "---" ; ssh -o StrictHostKeyChecking=no $host sha256sum /var/www/html/gmi-images/${1}.* ; ssh -o StrictHostKeyChecking=no $host ls -lash /var/www/html/gmi-images/${1}.* ; done
}

function dce_output () {
  ssh network-labs-80a8afc.cp1-iad.github.net sha256sum /var/lib/jenkins/workspace/dce-core-services/output/${1}.*
  ssh network-labs-80a8afc.cp1-iad.github.net ls -lash /var/lib/jenkins/workspace/dce-core-services/output/${1}.*
}

function dce_encrypted () {
  ssh network-labs-80a8afc.cp1-iad.github.net sha256sum /var/lib/jenkins/workspace/dce-core-services/encrypted/${1}.*
  ssh network-labs-80a8afc.cp1-iad.github.net ls -lash /var/lib/jenkins/workspace/dce-core-services/encrypted/${1}.*
}

function pb () {
  pbcopy
}

function go-switch () {
  VERSION=${1}
  cat <<EOF > /tmp/go-switch
    apt update && \
    apt install -y git wget ; \
    cd /tmp && \
    wget https://dl.google.com/go/go${VERSION}.darwin-amd64.tar.gz && \
    tar -C /usr/local -xzf go${VERSION}.darwin-amd64.tar.gz
EOF
  bash /tmp/go-switch
}

# function setup-dlv {
#   VERSION=1.10.4
#   cat <<EOF > /tmp/dlv
#   apt update && \
#   apt install -y git wget ; \
#   cd /tmp && \
#   wget https://dl.google.com/go/go${VERSION}.linux-amd64.tar.gz && \
#   tar -C /usr/local -xzf go${VERSION}.linux-amd64.tar.gz && \
#   mkdir /go && \
#   export PATH=\$PATH:/usr/local/go/bin:~/go/bin:/go/bin && \
#   export GOPATH=/go && \
#   go get -u github.com/derekparker/delve/cmd/dlv
# EOF
#   cat /tmp/dlv | pbcopy
#   echo "Setup steps to clipboard"
# }

function destroy {
  echo ".instance destroy hostname=$1 magic_word=" | pbcopy
  echo "Copied to clipboard"
}

function whatis {
  for f in $(find ~/github/network/ | grep llocat); do grep --color -C4 $1 $f; done
}

function pr {
  EDITOR="atom -w" hub pull-request
}

function waitci {
  while true; do sleep 5; hub ci-status | grep -v -e pending -e "no status" && break; done
}

function clone {
  cd ~/github
  git clone git@github.com:github/${1}.git
}

function crun {
 docker exec --detach-keys "ctrl-a,a" --tty --env="TERM=xterm-256color" -ti $1 $@
}

function mr {
  git fetch --all
  git rebase origin/master
}

function nb {
  git checkout -b $@
}

function rmb {
  git branch -D $@
  git push --delete origin $@
}

function ops-default {
  echo .instance create app=ops role=default site=cp1-iad distribution=jessie type=general2v.t reservation=jcudit-test | pbcopy
  echo "Copied to clipboard"
}

function load_gpanel_am4_db {
  echo "Resetting current db"
  z gpnl
  bin/rake db:reset
  echo "Downloading db snapshot off of secondary host"
  ssh db-mysql-0e11f56.cp1-iad.github.net "mysqldump -u root --max-allowed-packet=128M --set-gtid-purged=OFF --single-transaction --ignore-table=gpanel_am4.audits --ignore-table=gpanel_am4.log_texts gpanel_am4 | gzip -9 --to-stdout" > /tmp/gpanel_am4.sql.gz
  gunzip /tmp/gpanel_am4.sql.gz
  echo "Downloading last 1000 entries from log_texts off of secondary host"
  ssh db-mysql-0e11f56.cp1-iad.github.net "mysqldump -u root --max-allowed-packet=128M --set-gtid-purged=OFF --single-transaction --where='1=1 ORDER BY id DESC LIMIT 1000' gpanel_am4 log_texts | gzip -9 --to-stdout" > /tmp/gpanel_am4_log_texts.sql.gz
  gunzip /tmp/gpanel_am4_log_texts.sql.gz
  echo "Loading db snapshot"
  PATH="/usr/local/opt/mysql@5.7/bin:$PATH" mysql -h 127.0.0.1 -u root gpanel_development < /tmp/gpanel_am4.sql
  PATH="/usr/local/opt/mysql@5.7/bin:$PATH" mysql -h 127.0.0.1 -u root gpanel_development < /tmp/gpanel_am4_log_texts.sql
  rm /tmp/gpanel_am4.sql
  rm /tmp/gpanel_am4_log_texts.sql
  echo "Complete"
}

function load_gpanel_db {
  echo "Resetting current db"
  z gpnl
  bin/rake db:reset
  echo "Downloading db snapshot off of secondary host"
  ssh db-mysql-0e11f56.cp1-iad.github.net "mysqldump -u root --max-allowed-packet=128M --set-gtid-purged=OFF --single-transaction --ignore-table=gpanel_production.audits --ignore-table=gpanel_production.log_texts gpanel_production | gzip -9 --to-stdout" > /tmp/gpanel_production.sql.gz
  gunzip /tmp/gpanel_production.sql.gz
  echo "Downloading last 1000 entries from log_texts off of secondary host"
  ssh db-mysql-0e11f56.cp1-iad.github.net "mysqldump -u root --max-allowed-packet=128M --set-gtid-purged=OFF --single-transaction --where='1=1 ORDER BY id DESC LIMIT 1000' gpanel_production log_texts | gzip -9 --to-stdout" > /tmp/gpanel_production_log_texts.sql.gz
  gunzip /tmp/gpanel_production_log_texts.sql.gz
  echo "Loading db snapshot"
  PATH="/usr/local/opt/mysql@5.7/bin:$PATH" mysql -h 127.0.0.1 -u root gpanel_development < /tmp/gpanel_production.sql
  PATH="/usr/local/opt/mysql@5.7/bin:$PATH" mysql -h 127.0.0.1 -u root gpanel_development < /tmp/gpanel_production_log_texts.sql
  rm /tmp/gpanel_production.sql
  rm /tmp/gpanel_production_log_texts.sql
  echo "Complete"
}

function rc {
  z gpnl
  bin/rails c
}

function rdc {
 PATH="/usr/local/opt/mysql@5.7/bin:$PATH" bin/rails dbconsole
}

function c {
  pkill chunkwm
  sleep 3
  l3
}

function gdc {
  git diff --cached
}

function gd {
  git diff
}

function gc {
  git commit -v
}

function gs {
  git status
}

function p {
  git add -p
}

function r {
  script/rspec $@
}

function rr {
  bundle exec rspec $@
}

function frc {
  git push --force
}

function grepo {
  git log -p -S $@
}

function l {
  git logg
}

function pl {
  git plog
}

function mn {
  git stash && \
  git checkout main && \
  git fetch --all && \
  git reset --hard origin/main
}

function m {
  git stash && \
  git checkout master && \
  git fetch --all && \
  git reset --hard origin/master
}

function push {
  git push -u origin $(git rev-parse --abbrev-ref HEAD)
}

function sqcommit {
  git commit --squash=HEAD -m "squashing"
}

function sqrebase {
  git rebase --autosquash -i origin/master
}

function bash_reference {
  url=https://gist.githubusercontent.com/LeCoupa/122b12050f5fb267e75f/raw/0d5d68312792b0c2d531e637384f1781d89cd611/bash-cheatsheet.sh
  dest=/tmp/bash_reference
  [[ -r $dest ]] || curl -s -o $dest $url
  less $dest
}

function l1 {
  printf "root horizontal 0.700\nleft_leaf\nright_leaf" > /tmp/layout
  chunkc tiling::desktop --deserialize /tmp/layout
}

function l3 {
  chunkc tiling::desktop --deserialize ~/scratch/chunk/l3
}

function l2 {
  chunkc tiling::desktop --deserialize ~/scratch/chunk/l2
}

function vdrac {
  open /Applications/VNC\ Viewer.app
  ssh -o StrictHostKeyChecking=no  -L 39393:127.0.0.1:590${2} $1
}

function drac {
  argument=$(gh-ipmi $1)
  if [ -z $(echo $1 | tr -d '0-9.') ]; then
    argument=$1
  fi

  pushd ~/github/gpanel
  bundle exec ruby lib/drac.rb $argument
  popd
}

deploy-ssh () {
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_gh_deploy_rsa -l deploy $@
}


function jump {
  site=$(gh-site $1)
  case $site in
    "lab-iad")
      echo gpanel-app2-cp1-stg.iad.github.net ;;
    "cp1-iad")
      echo dce-gpanel-fwml482.cp1-iad.github.net ;;
    "sdc42-sea")
      echo dce-gpanel-2ckxpd2.sdc42-sea.github.net ;;
    "am4-ams")
      echo 10.42.128.10 ;;
    "ac4-iad")
      echo 10.52.4.10 ;;
    "va3-iad")
      echo 10.48.4.10 ;;
  esac
}

function ipmi {
  site=$(gh-site $1)
  ip=$(gh-ipmi $1)
  shift 1
  cmd="ipmitool -H $ip -U root -P $(secret IPMI_NEW) -I lanplus $@ 2>/dev/null || \
    ipmitool -H $ip -U root -P $(secret IPMI_LEGACY) -I lanplus $@"
  case $site in
    "lab-iad")
      ssh -t gpanel-app2-cp1-stg.iad.github.net -- "$cmd" ;;
    "cp1-iad")
      deploy-ssh dce-gpanel-fwml482.cp1-iad.github.net -- "sudo $cmd" ;;
    "sdc42-sea")
      deploy-ssh dce-gpanel-2ckxpd2.sdc42-sea.github.net -- "sudo $cmd" ;;
  esac
}

function ff {
  for i in $(seq 1 3); do
    sed -ibk "/$1/d" ~/.ssh/known_hosts
    sed -ibk "/$(dig +short @10.127.5.10 $1)/d" ~/.ssh/known_hosts
  done
}

function lgn {
  sed -ibk "/$1/d" ~/.ssh/known_hosts
  ~/github/gpanel/script/ssh-expect root octocat11 $1
}

function pr-review {
  branch=$(git rev-parse --abbrev-ref HEAD)
  m
  git clean -df
  git diff --raw -p master..$branch > /tmp/$branch.patch
  git apply /tmp/$branch.patch
}

function container_id {
  docker ps | grep $1 | head -1 | awk '{print $1}'
}

function enter {
  docker exec --detach-keys "ctrl-a,a" --tty --env="TERM=xterm-256color" -ti $(container_id $1) /bin/bash -l
  # echo "Saving container"
  docker commit --message "$(date +%Y-%m-%d:%M)" $1 jcudit/enter:latest
}

gpanel-ssh () {
  ssh -i ~/github/network/etc/ssh/octonet1 github@$1
}

chassis_deprovision () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi

  deploy-ssh $(jump $1) -- "cd /data/gpanel/current && script/service_shim bundle exec rails r 'c = Chassis.find_by_serial_number(\"$1\"); c.deprovision!; c.reload; c'"
}

pxe-unserve () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi
  proxy=$(jump $1)

  deploy-ssh $proxy -- \
    "cd /data/gpanel/current && script/service_shim bundle exec rails r \
      'c = Chassis.find_by_serial_number(\"$1\");
       a = Attribute.where(attributable_id: c.host.id).where(key: \"instance:ipxe_chain_url\").first;
       a.value = \"http://10.127.5.20/dce-imager-from-gpanel.ipxe\";
       a.save
      '
    "
}

pxe-serve () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi
  proxy=$(jump $1)

  deploy-ssh $proxy -- \
    "cd /data/gpanel/current && script/service_shim bundle exec rails r \
      'c = Chassis.find_by_serial_number(\"$1\");
       a = Attribute.where(attributable_id: c.host.id).where(key: \"instance:ipxe_chain_url\").first;
       a.value = \"http://$proxy:8089/dce-imager-from-gpanel.ipxe\";
       a.save
      '
    "
}

chassis_raid () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi

  deploy-ssh $(jump $1) -- "cd /data/gpanel/current && script/service_shim bundle exec rails r 'c = Chassis.find_by_serial_number(\"$1\");  c.state = \"raid_for_network_bootable\"; c.save; c.reboot!; c.reload; c'"
}

chassis_ready () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi

  deploy-ssh $(jump $1) -- "cd /data/gpanel/current && script/service_shim bundle exec rails r 'c = Chassis.find_by_serial_number(\"$1\");  c.host.destroy if c.host.present?; c.reload; c.state = \"ready\"; c.save; c.reboot!; c.reload; c'"
}

chassis_fw () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi

  deploy-ssh $(jump $1) -- "cd /data/gpanel/current && script/service_shim bundle exec rails r 'c = Chassis.find_by_serial_number(\"$1\"); c.state = \"firmware_upgrade_for_validating\"; c.save;'"

  ipmi $1 chassis power cycle
}

chassis_reset () {
  if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 <serial>" >&2
    exit 1
  fi

  deploy-ssh $(jump $1) -- "cd /data/gpanel/current && script/service_shim bundle exec rails r 'c = Chassis.find_by_serial_number(\"$1\");  c.host.destroy if c.host.present?; c.reload; c.state = \"unknown\"; c.save; c.reboot!; c.reload; c'"
}

gpanel-console-am4 () {
  ssh github@10.42.128.10 -i ~/github/network/etc/ssh/octonet1 -- "sudo -u deploy /bin/bash -c 'cd /data/gpanel/current && script/service_shim bundle exec rails c -- --prompt simple'"
}

gpanel-console-cp1 () {
  deploy-ssh dce-gpanel-fwml482.cp1-iad.github.net -- "sudo -u deploy /bin/bash -c 'cd /data/gpanel/current && script/service_shim bundle exec rails c -- --prompt simple'"
}

gpanel-console-se3 () {
  deploy-ssh 10.36.128.7 -- "sudo -u deploy /bin/bash -c 'cd /data/gpanel/current && script/service_shim bundle exec rails c -- --prompt simple'"
}

gpanel-console-sdc42 () {
  deploy-ssh 10.44.130.8 -- "sudo -u deploy /bin/bash -c 'cd /data/gpanel/current && script/service_shim bundle exec rails c -- --prompt simple'"
}

gpanel-console-dc2 () {
  deploy-ssh 10.40.128.8 -- "sudo -u deploy /bin/bash -c 'cd /data/gpanel/current && script/service_shim bundle exec rails c -- --prompt simple'"
}

inventory-pstree () {
  printf 'watch -n0.5 "ps faux | sed \"0,/inventory-service.sh/d\""' | pbcopy
  echo "Copied to clipboard. Run on a box during inventory."
}

secret () {
  grep $1 ~/.ghrc-secrets | cut -d= -f2
}

token_name_for_site () {
  echo GPANEL_TOKEN_$(echo $1 | tr '[:lower:]' '[:upper:]' | tr '-' '_')
}

update-xx-cache () {
  endpoint=/api/v3/consumer/$1
  site=$2
  TOKEN_NAME=$(token_name_for_site $site)
  curl -vso /tmp/$1-$site.json https://$(secret $TOKEN_NAME)@gpanel.$site.github.net$endpoint
}

ci () {

  for site in $(sites);
  do
    [[ -a /tmp/instances-$site.json ]] || update-xx-cache instances $site
  done

  serial-in-site () {
    cat /tmp/chassis-$1.json | jq '.[] | .serial_number' | grep -q $2
  }

  get-serial () {
    cat /tmp/chassis-$1.json | jq '.[] | select(.serial_number == "'"$2"'")'
  }

  for site in $(sites);
  do
    serial-in-site $site $1 && get-serial $site $1 && return
  done

  return 1
}

sites () {
  # echo "cp1-iad sdc42-sea dc2-iad se3-sea am4-ams"
  echo "ac4-iad va3-iad cp1-iad sdc42-sea dc2-iad se3-sea"
}

ii () {
  for site in $(sites);
  do
    [[ -a /tmp/instances-$site.json ]] || update-xx-cache instances $site
  done

  instance-in-site () {
    cat /tmp/instances-$1.json | jq -r '.[] | .fqdn' | grep $2
  }

  get-instance () {
    host=$(echo $2 | head -1)
    cat /tmp/chassis-$1.json | jq '.[] | select(.fqdn == "'"$host"'")'
  }

  for site in $(sites);
  do
    fqdn=$(instance-in-site $site $1)
    [[ ! -z $fqdn ]] && get-instance $site $fqdn && return 0
  done

  return -1
}

pi () {
  for site in $(sites);
  do
    cat /tmp/instances-$site.json | jq '.[] | select(.primary_ip_address == "'"$1"'")'
  done
}

whereis () {
  SITE=$(gh-site $1)
  TOKEN_NAME=$(token_name_for_site $SITE)
  curl -s https://$(secret $TOKEN_NAME)@gpanel.$SITE.github.net/chasses/$(gh-serial $1) | \
    grep "located at" | sed 's/.*located at //' | sed 's/Slots/Rack Units/'
}

iip () {
  SITE=$(gh-site $1)
  TOKEN_NAME=$(token_name_for_site $SITE)
  curl -s https://$(secret $TOKEN_NAME)@gpanel.$SITE.github.net/chasses/$(gh-serial $1)/provisioning_logs | egrep "\d+\.\d+\.\d+\.\d+" > /tmp/iip
  head -1 /tmp/iip | cut -d: -f 2 | tr -d ' ' | pbcopy
  cat /tmp/iip
  echo "First IP copied to clipboard"
}

gh-hostname () {
  ii $1 | jq -r '.fqdn'
  for site in $(sites); do
    ci $1 | jq -r '.fqdn'
  done | sort | uniq | head -1
}

gh-serial () {
  ii $1 | jq -r '.serial_number'
  ci $1 | jq -r '.serial_number'
}

gh-ipmi () {
  ii $1 | jq -r '.ipmi_ip'
  ci $1 | jq -r '.ipmi_ip'
}

gh-site () {
  gh-hostname $1 | rev | cut -d. -f 3 | rev
}

check_megaraid_sas () {
  ssh $(gh-hostname $1) \
    "sudo /opt/puppet/modules/megaraid/files/usr/local/sbin/check_megaraid_sas || sudo /usr/local/sbin/check_megaraid_sas"
}

disk_triage () {
  # Media Errors
  ssh $(gh-hostname $1) \
  "sudo /opt/MegaRAID/MegaCli/MegaCli64 -PDList -aALL | grep -e '^Enclosure' -e \
    '^Slot' -e '^Media Error' | grep -e '^Media Error Count: [^0]' -B 2"

  # Smart Errors
  ssh $(gh-hostname $1) \
  "sudo /opt/MegaRAID/MegaCli/MegaCli64 -PDList -aALL | grep -e '^Enclosure Device' \
    -e '^Slot' -e '^Drive has flagged' | grep -e 'Yes' -B 2"

  # Missing
  ssh $(gh-hostname $1) \
    "sudo /opt/MegaRAID/MegaCli/MegaCli64 -PDList -aALL | grep -i -E '(slot number|status)'"

  # Alert Output
  check_megaraid_sas $1
}

disk_ticket () {
  URL=""
  if [[ $(gh-site $1) =~ "iad" ]]; then
    URL="https://qts.service-now.com/com.glideapp.servicecatalog_cat_item_view.do?v=1&sysparm_id=fdb550526f709d40db4ffee09d3ee46d&sysparm_link_parent=c3d3e02b0a0a0b12005063c7b2fa4f93&sysparm_catalog=e0d08b13c3330100c8b837659bba8fb4&sysparm_catalog_view=catalog_default"
  else
    URL="https://sabey.force.com/customerportal/sbyCreateTicket"
  fi

  SUBJECT="Disk replacement for $(gh-serial $1)"
  WHERE="$(whereis $1)"

  BODY="Please receive a replacement drive from Dell and replace the drive in slot "
  BODY+="<slot> (numbered 0 through <slot_max>) "
  BODY+="on the chassis with serial number $(gh-serial $1) "
  BODY+="located at $WHERE."

  echo "$SUBJECT" | pbcopy
  sleep 0.5
  echo "$BODY" | pbcopy
  sleep 0.5
  echo "$WHERE" | pbcopy

  echo "Adding the following to the clipboard:"
  echo $SUBJECT
  echo $BODY
  echo $WHERE

  open $URL
}

sshnet () {
  ssh -i ~/github/network/etc/ssh/octonet1 -x -l octonet1 $1
}

function _rspec_command () {
  if [ -e "bin/rspec" ]; then
   bin/rspec $@
   else
     rspec $@
  fi
}

alias rspec='_rspec_command'

ssh-rec () {
  DEST=~/Documents/casts/$(date +%Y-%m-%d:%M:%S).${1}.cast
  /usr/local/bin/asciinema rec -c "ssh $@" $DEST || /usr/bin/ssh $@
}

function commit-review {
  m
  START=$1

  if [ "$#" -ne 1 ]; then
    END=$2
    git diff --raw -p ${START}..${END} > /tmp/${START}.patch
  else
    git diff --raw -p ${START}~1..${START} > /tmp/${START}.patch
  fi

  git checkout ${START}~1
  git apply /tmp/${START}.patch
}

puppet-pstree () {
  printf 'watch -d -n0.5  "ps faux | grep -A 15 /etc/rc.local | grep -v grep"' | pbcopy
  echo "Copied to clipboard. Run on a box going through a puppet run"
}

function vndr-logs () {
 kubectl logs $(kubectl get pods -n vndr-production | grep Running | awk '{print $1}') -n vndr-production -c vndr
}

function vndr-host () {
  kubectl describe pods -n vndr-production  | egrep "^Node:" | cut -d: -f2 | cut -d/ -f1 | tr -d ' '
}

function title {
    echo -ne "\033]0;"$*"\007"
}

function ring {
  ssh github@freifunkrl01.ring.nlnog.net
}

function dun {
  while true; do say done; done
}


gpanel-console-ip () {
  ssh github@$1 -tt \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o IdentitiesOnly=yes \
    -i ~/github/network/etc/ssh/octonet1 -- \
    "sudo -u deploy /bin/bash -c 'cd /data/gpanel/current && script/service_shim bundle exec pry -r ./config/environment'"
}
gpanel-console-se3 () {
  gpanel-console-ip 10.36.128.7
}
gpanel-console-sdc42 () {
  gpanel-console-ip 10.44.130.8
}
gpanel-console-cp1 () {
  gpanel-console-ip 172.16.40.24
}
gpanel-console-dc2 () {
  gpanel-console-ip 10.40.128.8
}
gpanel-console-am4 () {
  gpanel-console-ip 10.42.128.10
}
gpanel-console-ac4 () {
  gpanel-console-ip 10.52.4.10
}
gpanel-console-va3 () {
  gpanel-console-ip 10.48.4.10
}
