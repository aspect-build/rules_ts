import { ConnectRouter } from '@bufbuild/connect'
import { ElizaService } from './proto/eliza_connect.js'

export default (router: ConnectRouter) =>
    // registers connectrpc.eliza.v1.ElizaService
    // TODO(alexeagle): why do we need to Put an `any` on it?
    router.service(ElizaService as any, {
        // implements rpc Say
        async say(req) {
            return {
                sentence: `You said: ${req.sentence}`,
            }
        },
    })
