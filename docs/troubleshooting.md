# Troubleshooting ts_project failures

`ts_project` is a thin wrapper around the [`tsc` compiler from TypeScript](https://www.typescriptlang.org/docs/handbook/compiler-options.html). Any code that works with `tsc` should work with `ts_project` with a few caveats:

- `ts_project` always produces some output files, or else Bazel would never run it.
    Therefore you shouldn't use it with TypeScript's `noEmit` option.
    If you only want to test that the code typechecks, use `tsc` directly.
    See [examples/typecheck_only](/examples/typecheck_only/BUILD.bazel)
- Your tsconfig settings for `outDir` and `declarationDir` are ignored.
    Bazel requires that the `outDir` (and `declarationDir`) be set beneath
    `bazel-out/[target architecture]/bin/path/to/package`.
- Bazel expects that each output is produced by a single rule.
    Thus if you have two `ts_project` rules with overlapping sources (the same `.ts` file
    appears in more than one) then you get an error about conflicting `.js` output
    files if you try to build both together.
    Worse, if you build them separately then the output directory will contain whichever
    one you happened to build most recently. This is highly discouraged.

You can often create a minimal repro of your problem outside of Bazel.
This is a good way to bisect whether your issue is purely with TypeScript, or there's something
Bazel-specific going on.

# Not reproducible ts_project worker bugs
Not reproducible ts_project, a.k.a. state, bugs has been a challenge for anyone to diagnose and possibly, fix in ts_project. 
Not knowing what state the worker has been at when it falsely failed, or what went wrong along the way is hard to know.
For this, we introduced support  for `--worker_verbose` flag which prints a bunch of helpful logs to worker log file.

If you find yourself getting yelled at by ts_project falsely on occasion, drop `build --worker_verbose` to the `.bazelrc` file.
In addition to `--worker_verbose`, set `extendedDiagnostics` and `traceResolution` to true in the `tsconfig.json` file to log
additional information about how tsc reacts to events fed by worker protocol. 

```
{
    "compilerOptions": {
        "extendedDiagnostics": true,
        "traceResolution": true
    }
}
```

Next time, the ts_project yields false negative diagnostics messages, collect the logs files output_base and file a bug with the log files.

To collect log files run the command below at the workspace directory and attach the logs.tar file to issued file.
```
tar -cf logs.tar $(ls $(bazel info output_base)/bazel-workers/worker-*-TsProject.log)
```

This will help us understand what went wrong in your case, and hopefully implement a permanent fix for it.


# Getting unstuck

The basic methodology for diagnosing problems is:

1. Gather information from Bazel about how `tsc` is spawned, like with `bazel aquery //path/to:my_ts_project`.
1. Reason about whether Bazel is providing all the inputs to `tsc` that you expect it to need. If not, the problem is with the dependencies.
1. Reason about whether Bazel has predicted the right outputs.
1. Gather information from TypeScript, typically by adding flags to the `args` attribute of the failing `ts_project`, as described below. Be prepared to deal with a large volume of data, like by writing the output to a file and using tools like an editor or unix utilities to analyze it.
1. Reason about whether TypeScript is looking for a file in the wrong place, or writing a file to the wrong place.

## Which files should be emitted

TypeScript emits for each file in the "Program". `--listFiles` is a `tsc` flag to show what is in the program, and `--listEmittedFiles` shows what was written.

Upgrading to TypeScript 4.2 or greater can be helpful, because error messages were improved, and new flags were added.

TS 4.1:
```
error TS6059: File '/private/var/tmp/_bazel_alex.eagle/efa8e81f99c35c1227ef40a83cd29a26/execroot/examples_jest/ts/test/index.test.ts' is not under 'rootDir' '/private/var/tmp/_bazel_alex.eagle/efa8e81f99c35c1227ef40a83cd29a26/execroot/examples_jest/ts/src'. 'rootDir' is expected to contain all source files.
Target //ts/src:src failed to build
```

TS 4.2:
```
error TS6059: File '/private/var/tmp/_bazel_alex.eagle/efa8e81f99c35c1227ef40a83cd29a26/execroot/examples_jest/ts/test/index.test.ts' is not under 'rootDir' '/private/var/tmp/_bazel_alex.eagle/efa8e81f99c35c1227ef40a83cd29a26/execroot/examples_jest/ts/src'. 'rootDir' is expected to contain all source files.
  The file is in the program because:
    Matched by include pattern '**/*' in 'tsconfig.json'
```

The `--explainFiles` flag in TS 4.2 also gives information about why a given file was added to the program.

## Module not resolved

Use the `--traceResolution` flag to `tsc` to understand where TypeScript looked for the file.

Verify that there is actually a `.d.ts` file for TypeScript to resolve. Check that the dependency library has the `declarations = True` flag set, and that the `.d.ts` files appear where you expect them under `bazel-out`.

## TS5033: EPERM 

```
error TS5033: Could not write file 'bazel-out/x64_windows-fastbuild/bin/setup_script.js': EPERM: operation not permitted, open 'bazel-out/x64_windows-fastbuild/bin/setup_script.js'.
```
This likely means two different Bazel targets tried to write the same output file. Use `--listFiles` to ask `tsc` to show what files are in the program. Try `--explainFiles` (see above) to see how they got there.

You may find that the program contained a `.ts` file rather than the corresponding `.d.ts` file.

Also see https://github.com/microsoft/TypeScript/issues/22208 - it's possible that TypeScript is resolving a `.ts` input where it should have used a `.d.ts` from another compilation.
