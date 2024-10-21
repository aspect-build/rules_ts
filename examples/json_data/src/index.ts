const fs = require('fs')
const path = require('path')

const dataFiles = [
    './asset.txt',
    './fg.json',
    './fg.txt',
    './src.json',
    './tsdata.json',
    './tsdata.txt',
]

fs.writeFileSync(
    path.join(process.argv[2], 'all.txt'),
    dataFiles.map((f) => fs.readFileSync(path.join(__dirname, f))).join('')
)
