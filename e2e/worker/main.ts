import * as feature1 from "./feature1";
import * as feature2 from "./feature2";
import * as feature3 from "./feature3";
import * as feature4 from "./feature4";
import * as feature from "./feature";
import * as debug from "debug";

import * as common from "@nestjs/common";
import * as core from  "@nestjs/core";
import * as rxjs from "rxjs";

console.log(common, core, rxjs);

const features = [
    feature.name,
    feature1.name,
    feature2.name,
    feature3.name,
    feature4.name,
]

function sayhello(should_i) {
    if (should_i) {
        debug.log(features);
    }
}