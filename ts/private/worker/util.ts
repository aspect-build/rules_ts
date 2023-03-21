import {debug} from "./debugging"

export function notImplemented<T>(name: string, _throw: boolean, _returnArg: number) {
    return (...args: unknown[]) => {
        if (_throw) {
            throw new Error(`function ${name} is not implemented.`);
        }
        debug(`function ${name} is not implemented.`);
        return args[_returnArg] as T;
    }
}


export function noop(..._: unknown[]): void { }
