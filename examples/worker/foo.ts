import {whoami} from "./dir/this";

export const a: string = whoami;

function name(params) {
    // implicitly any. 
    // we'll write a test to ensure that worker can pick up tsconfig changes and report errors correctly.
}