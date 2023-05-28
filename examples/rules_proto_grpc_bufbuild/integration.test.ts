import { createGrpcServer } from "./server";
import { createNodeClient } from "./client_node";
import { GreetRequest } from "./example_pb";

describe("Node client-server grpc communication", () => {
    const server = createGrpcServer(8080);
    const client = createNodeClient("http://localhost:8080");

    afterAll(() => {
        server.close();
    })

    it("Works", async () => {
        const request = new GreetRequest({ name: "Mr. Example" });
        const response = await client.greet(request);
        expect(response.greeting).toBe("Greetings, Mr. Example!");
    })
})