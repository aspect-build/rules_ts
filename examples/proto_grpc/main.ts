import { LogMessageSchema } from './logger_pb.js'
import { EmptySchema } from './stripping/s_pb.js'
import { create, fromBinary, toBinary } from '@bufbuild/protobuf'

let msg = create(LogMessageSchema, { message: 'hello world' })
create(EmptySchema, {})

// Reference the inherited `.toBinary()` to ensure types from transitive types are included.
msg = fromBinary(LogMessageSchema, toBinary(LogMessageSchema, msg))

console.log(JSON.stringify(msg))
