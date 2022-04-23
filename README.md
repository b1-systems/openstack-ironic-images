# openstack-ironic-images

This repository is used to manage build recipes for creating images for use on baremetal systems.

| OS         | Version | Architecture |
|------------|---------|--------------|
| Ubuntu     | 20.04   | x86_64       |

## Build

```
packer build ubuntu-20.04-amd64.json
```

## Download

Prebuilt images can be downloaded from https://minio.services.osism.tech/openstack-ironic-images/.

There is always a file compressed with GZIP and the file it contains in uncompressed form.

If possible please download the compressed file.
