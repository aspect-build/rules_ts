

let VERBOSE = false;
export function debug(...args: unknown[]) {
    VERBOSE && console.error(...args);
}

export function setVerbosity(level: number) {
    // bazel set verbosity to 10 when --worker_verbose is set. 
    // See: https://bazel.build/remote/persistent#options
    VERBOSE = level > 0;
}

export function isVerbose() {
    return VERBOSE
}