# Package Structure
```
[package name]
|- skyhook_dir
|   |- ...
|- root_dir
|   |- ...
|- config.json
|- Dockerfile
```

## skyhook_dir
The `skyhook_dir` should contain any scripts you will use in your steps as well as any static files your scripts might want to reference.

## root_dir
The `root_dir` will be copied into the root filesystem directly. For example a root_dir structure of:
```
root_dir
|- etc
   |- hosts
```
Would overwrite the /etc/hosts file on the node it was run on.

## config.json
This is the configuration file for the package and must match the [skyhook agent schema](github.com/nvidia/skyhook/...)

## Dockerfile
Copy the `skyhook_dir`, `root_dir` and `config.json` to `/skyhook-package`

# Building a package
1. `docker buildx create builder`
2. `docker buildx build -t {package}:{tag} -f {dockerfile} --platform={','.join(f'linux/{arch}' for arch in architectures)} --push {package directory}"`

# Repository Rules
* All commits MUST be in a conventional commit format with the package name as the object. If it is NOT for a package then it should be prefixed with `general/` Examples:
   * feat(shellscript): Add support for uninstall
   * fix(tuning): Post-interrupt check for containerd changes did not allow of infinity setting
   * docs(general/ci): Update the main README.md for how CI works
* Tags are 1:1 with a package. In the format `{package}/{version}`
* Versions of packages MUST be [semver](https://semver.org/)
* CI builds packages on tag