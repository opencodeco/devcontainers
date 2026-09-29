# ⌨️ Development Containers goodies

> A development container (or dev container for short) allows you to use a container as a full-featured development environment. It can be used to run an application, to separate tools, libraries, or runtimes needed for working with a codebase, and to aid in continuous integration and testing. Dev containers can be run locally or remotely, in a private or public cloud, in a variety of supporting tools and editors. - https://containers.dev

## Install PHP extensions

The `install-php-extensions` feature installs PHP extensions. Set `extensions` to names separated by spaces or commas, for example `zip` or `zip, gd`.

Official images from https://hub.docker.com/_/php provide `docker-php-ext-install`, `docker-php-ext-configure`, `docker-php-ext-enable`, and `docker-php-source`. On those images the feature runs [mlocati/docker-php-extension-installer](https://github.com/mlocati/docker-php-extension-installer) 2.2.5.

Debian and Ubuntu images such as `mcr.microsoft.com/devcontainers/base` do not provide those commands. On those images the feature installs `php-cli` and the distro package for each extension. `zip` installs `php-zip`. Apt repositories from the image choose the PHP version.

Official PHP image:

```json
{
  "image": "php:8.3-cli",
  "features": {
    "ghcr.io/opencodeco/devcontainers/install-php-extensions": {
      "extensions": "zip"
    }
  }
}
```

Debian or Ubuntu image:

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

Any other image fails before mlocati/docker-php-extension-installer is downloaded. The error names both supported bases.

See [features/install-php-extensions/README.md](features/install-php-extensions/README.md).
