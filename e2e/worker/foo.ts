import {name, version} from "./lib";

function sayhello(should_i) {
    if (should_i) {
        console.log(name, version);
    }
}