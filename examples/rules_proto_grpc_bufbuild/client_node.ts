import { createPromiseClient, PromiseClient } from "@bufbuild/connect";
import { createGrpcTransport } from "@bufbuild/connect-node";
import { ExampleService } from "./example_connect";

export function createNodeClient(baseUrl: string): PromiseClient<typeof ExampleService> {
    const transport = createGrpcTransport({
        baseUrl,
        httpVersion: "2"
    });

    return createPromiseClient(ExampleService, transport);
}