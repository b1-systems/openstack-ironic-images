# openstack-ironic-images

This repository is used to manage build recipes for creating images for use on baremetal systems.

| OS         | Version | Architecture |
|------------|---------|--------------|
| Ubuntu     | 22.04   | x86_64       |

## Build

```shell
sudo mkosi --force build
```

## Download

Files can be downloaded as releases here in the repository. Both as `.raw` and `.qcow2`.