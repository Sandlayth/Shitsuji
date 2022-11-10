# Shitsuji
Puppet manifests to manage my personal devices

Check syntax and linting of manifest and tests:
```
pdk validate
```

Run unit tests:
```
pdk test unit
```

Apply a role locally:
```
sudo bolt plan -t localhost roles::<my_role> --verbose
```
