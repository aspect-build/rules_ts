import { createPromiseClient, PromiseClient } from "@bufbuild/connect";
import { createGrpcWebTransport } from "@bufbuild/connect-web";
import { ExampleService } from "./example_connect";

export function createWebClient(baseUrl: string): PromiseClient<typeof ExampleService> {
    const transport = createGrpcWebTransport({
        baseUrl,
    });

    return createPromiseClient(ExampleService, transport);
}