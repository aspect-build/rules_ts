// @ts-ignore
const { readdirSync } = require("node:fs");

console.log(readdirSync(".").includes("data.txt"));
