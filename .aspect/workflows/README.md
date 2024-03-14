# Aspect Workflows demonstration deployment

This deployment of [Aspect Workflows](https://www.aspect.build/workflows) is configured to run on GitHub Actions.

You can see this Aspect Workflows demonstration deployment live at
https://github.com/aspect-build/rules_ts/actions/workflows/aspect-workflows.yaml.

The two components of the configuration in this repository are,

1. Aspect Workflows configuration yaml
1. GitHub Actions workflows configurations

## Aspect Workflows configuration yaml

This is the [config.yaml](./config.yaml) file in this directory.

## GitHub Actions workflows configurations

This includes 3 files:

1.  [.github/workflows/aspect-workflows.yaml](../../.github/workflows/aspect-workflows.yaml) : Aspect Workflows CI workflow

1.  [.github/workflows/aspect-workflows-warming.yaml](../../.github/workflows/aspect-workflows-warming.yaml) : Aspect Workflows warming cron workflow

1.  [.github/workflows/.aspect-workflows-reusable.yaml](../../.github/workflows/.aspect-workflows-reusable.yaml) : Aspect Workflows Reusable Workflow for GitHub Actions.
    This files is kept up-to date with the [upstream](https://github.com/aspect-build/workflows-action/blob/main/.github/workflows/.aspect-workflows-reusable.yaml) source-of-truth with a `write_source_file` target in [.github/workflows/BUILD.bazel](../../.github/workflows/BUILD.bazel).
