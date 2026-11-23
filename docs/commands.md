# Commands

## Git

### Initialize repo

```bash
git init
```

### Disable fast-forward merges

```bash
git merge --no-ff
```

## Git diff

```bash
# All unstaged + staged changes
git diff HEAD --output=path/to/file.txt
# Only staged changes
git diff --staged
```

## Unpack tarball

```bash
tar -xf filename.tar.gz
```

## Give github action script exec permission

```bash
chmod +x build.sh
git add --chmod=+x build.sh
git commit -m "ci: mark build.sh as executable"
```
