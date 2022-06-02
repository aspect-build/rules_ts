import * as feature1 from "./feature1";
import * as feature2 from "./feature2";
import * as feature3 from "./feature3";
import * as feature from "./feature";

const features = [
    feature.name,
    feature1.name,
    feature2.name,
    feature3.name,
]

function sayhello(should_i) {
    if (should_i) {
        console.log(features)
    }
}