import { createServer, Http2Server } from "http2";
import { ConnectRouter } from "@bufbuild/connect";
import { connectNodeAdapter } from "@bufbuild/connect-node";
import { ExampleService } from "./example_connect";
import { GreetRequest } from "./example_pb";

function exampleServiceRoutes(router: ConnectRouter) {
    router.service(ExampleService, {
        async greet(req: GreetRequest) {
            return {
                greeting: `Greetings, ${req.name}!`
            }
        },
    });
}

export function createGrpcServer(port: number): Http2Server {
    const router = connectNodeAdapter({ routes: exampleServiceRoutes });
    return createServer(router).listen(8080);
}