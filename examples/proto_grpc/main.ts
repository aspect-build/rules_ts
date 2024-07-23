import { LogMessage } from './logger_pb.js'

let msg = LogMessage.fromJson({ message: 'hello world' })

// Reference the inherited `.toBinary()` to ensure types from transitive types are included.
msg = LogMessage.fromBinary(msg.toBinary())

console.log(JSON.stringify(msg))
