set -x
git checkout master
git fetch gg
git pull --rebase
git rebase gg/master
git push --force origin master

git checkout bodhiserver_lastcommit
git pull --rebase
git checkout -b bodhiserver_newcommit
git rebase origin/master

cd examples/server/test && pip install -r requirements.txt && pytest
git push -u origin bodhiserver_newcommit

git checkout master