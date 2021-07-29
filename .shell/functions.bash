
co () {
  git checkout $@
}

rebma () {
  git fetch --all; git rebase origin/master
}

rebmn () {
  git fetch --all; git rebase origin/main
}

nb () {
  git checkout -b $@
}

rmb () {
  git branch -D $@
  git push --delete origin $@
}

gdc () {
  git diff --cached
}

gd () {
  git diff
}

gc () {
  git commit -v
}

gs () {
  git status
}

p () {
  git add -p
}

frc () {
  git push --force
}

l () {
  git log
}

mn () {
  git stash && \
  git checkout main && \
  git fetch --all && \
  git reset --hard origin/main
}

m () {
  git stash && \
  git checkout master && \
  git fetch --all && \
  git reset --hard origin/master
}

push () {
  git push -u origin $(git rev-parse --abbrev-ref HEAD)
}

sqcommit () {
  git commit --squash=HEAD -m "squashing"
}

sqrebase () {
  git rebase --autosquash -i origin/master
}
