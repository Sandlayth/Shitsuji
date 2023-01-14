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

Install puppet dependencies
```
bolt module install
```

Apply a role locally:
```
sudo bolt plan -t localhost run roles::<my_role> --verbose
```
