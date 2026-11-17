# Git

## Initialize repo

```bash
git init
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
