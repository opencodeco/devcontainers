# Install PHP extensions

Installs PHP extensions in a development container.

## Supported images

Official Docker PHP images from https://hub.docker.com/_/php include `docker-php-ext-install`, `docker-php-ext-configure`, `docker-php-ext-enable`, and `docker-php-source`. On those images this feature downloads [mlocati/docker-php-extension-installer](https://github.com/mlocati/docker-php-extension-installer) 2.2.5 and runs it.

Debian and Ubuntu images, including `mcr.microsoft.com/devcontainers/base`, do not include those commands. On those images this feature installs `php-cli` and the distro package for each extension. `zip` installs `php-zip`. Apt repositories from the image choose the PHP version.

Any other image stops before that installer is downloaded. The error names both supported bases. This feature does not add fake `docker-php-ext-*` commands to look like an official PHP image.

## Options

`extensions` is a string of extension names separated by spaces or commas. Example: `zip` or `zip, gd`.

## Example

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:bullseye",
  "features": {
    "ghcr.io/opencodeco/devcontainers/install-php-extensions": {
      "extensions": "zip"
    }
  }
}
```

## Checks

From the repository root:

```bash
bash tests/install-php-extensions.sh
```

That check does not build an image and does not install packages.
