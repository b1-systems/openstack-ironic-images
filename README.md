# openstack-ironic-images

This repository is used to manage build recipes for creating images for use on baremetal systems.

| OS         | Version | Architecture |
|------------|---------|--------------|
| Ubuntu     | 22.04   | x86_64       |

## Build

```shell
sudo mkosi --force build
```

This outputs a directory tree in `mkosi.output` which than can be used for post-processing.

To create releases on GitHub, the additional script [`create_disk_image.sh`](./create_disk_image.sh) is used. It requires `IMAGE_ID` and `IMAGE_VERSION` as input. See the [CI definition](.github/workflows/ci.yaml) on how those variables are defined.

## Download

Files can be downloaded as releases here in the repository. Both as `.raw.zst` and `.qcow2`.

Due to [quota on GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#storage-and-bandwidth-quotas) released files can only be 2 GiB or smaller.

After downloading all the single chunks, they can be combined with `cat`.

```shell
cat "${IMAGE_NAME}.qcow2"* > "${IMAGE_NAME}.qcow2"
cat "${IMAGE_NAME}.raw.zst"* | zstd -d - > "${IMAGE_NAME}.raw"
```

The `.sha256` file both contains the checksums for the different chunks as well as the whole file.
