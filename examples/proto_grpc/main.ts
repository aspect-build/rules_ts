import { LogMessage } from './logger_pb.js'

const msg = LogMessage.fromJson({ message: 'hello world' })

console.log(JSON.stringify(msg))
